#!/opt/local/bin/perl
use Mojolicious::Lite;
use 5.012;
use FindBin;
use JSON qw{decode_json};
use lib $FindBin::Bin . '/lib';
use lib $FindBin::Bin . '/extlib';
use LangCollab::Schema;
use WWW::Github::Files;

app->log->level('error');

my $config = plugin 'Config';
app->secret( $config->{cookie_secret} );

my @token_chars = ('a'..'z', 'A'..'Z', '0'..'9');
my $github_api = 'https://api.github.com';

my $db = LangCollab::Schema->connect(
    'dbi:mysql:dbname=' . $config->{database_table}, 
    $config->{database_user}, 
    $config->{database_password}
    );

get '/' => sub {
    my $self = shift;
    $self->render('index');
};

get '/login/oauth_start' => sub {
    my $self = shift;
    return $self->redirect_to( $self->oauth_obj->authorize );
};

get '/login/oauth_login' => sub {
    my $self = shift;
    my $code = $self->param('code');
    my $access_token = $self->oauth_obj->get_access_token($code);
    my $data = $self->oauth_request($access_token, '/user');
    my $user_id = $data->{id};
    my $token = join '', map { $token_chars[int(rand(scalar(@token_chars)))] } 1..20;
    my $user_data = { };
    foreach my $key (qw{url name email}) {
        $user_data->{$key} = $data->{$key};
    }
    my $user_class = $db->resultset('User');
    my $user_obj = $user_class->find($user_id);
    if ($user_obj) {
        $user_obj->oauth_token($access_token);
        $user_obj->user_data($user_data);
        $user_obj->token($token);
        $user_obj->update();
    }
    else {
        $user_obj = $user_class->new({ id => $user_id, token => $token });
        $user_obj->oauth_token($access_token);
        $user_obj->user_data($user_data);
        $user_obj->insert();
    }
    $self->session({ user_id => $user_id, token => $token });
    $self->session(expiration => 604800);
    $self->redirect_to( $self->url_for('/app/home') );
};

group { 

    under '/app' => sub {
        my $self = shift;
        my $user_id = $self->session->{user_id};
        my $token = $self->session->{token};
        if (not $user_id or not $token) {
            $self->render(text => 'Please login id('.($user_id // '').') token('.($token // '').')');
            return;
        }
        my $user = $db->resultset('User')->find($user_id);
        if (not $user or $token ne $user->token()) {
            $self->render(text => 'Please login ' . ($user ? "user defined" : "user undef") . " |$token|".$user->token()."|");
            return;
        }
        $self->stash(user_obj => $user);
        $self->stash(user_data => $user->user_data());
        return 1;
    };

    get '/logout' => sub {
        my $self = shift;
        $self->session( {user_id => 0, token => 'xxxxxxxxxxxxx'} );
        $self->session( expires => 1 );
        my $user = $self->stash('user_obj');
        $user->token('');
        $user->update();
        $self->redirect_to( $self->url_for('/') );
    };

    get '/home' => sub {
        my $self = shift;
        my $user_obj = $self->stash('user_obj');
        my @prjs = $db->resultset('Project')->search({ owner => $user_obj->id() })->all();
        $self->stash('self_prjs' => \@prjs);
        $self->render('app/home');
    };

    get '/home/register_resp_dialog' => sub {
        my $self = shift;
        my $user_obj = $self->stash('user_obj');
        my $access_token = $self->get_user_oauth();
        my $data = $self->oauth_request($access_token, '/user/repos?type=owner');
        my @resps;
        foreach my $rec (@$data) {
            push @resps, { 
                fullname => $rec->{full_name},
                description => $rec->{description},
            };
        }
        $self->stash('resp_data', \@resps);
        $self->render('app/home/register_resp_dialog');
    };

    get '/home/do_register_resp' => sub {
        my $self = shift;
        # name is in the format of owner/resp_name
        my $resp_name = $self->param('name');
        my $access_token = $self->get_user_oauth();
        my $resp_data = $self->oauth_request($access_token, "/repos/$resp_name");
        my $branch_data = $self->oauth_request($access_token, "/repos/$resp_name/branches");
        my $prj = $db->resultset('Project')->new({
            url => $resp_data->{html_url},
            owner => $self->stash('user_obj')->id(),
            resp_name => $resp_name,
            description => $resp_data->{description},
            master_branch => $resp_data->{master_branch},
            dev_branch => $resp_data->{master_branch},
            });
        $prj->insert();
        if (@$branch_data == 1) {
            return $self->redirect_to( $self->url_for('/app/home') );
        }
        my @b_names = map $_->{name}, @$branch_data;
        $self->stash('branch_names', \@b_names);
        $self->stash('prj', $prj);
        $self->render('app/home/configure_resp');
    };

    get '/home/unregister_resp' => sub {
        my $self = shift;
        my $resp_name = $self->param('name');
        my $user_obj = $self->stash('user_obj');
        my $prj = $db->resultset('Project')->search(
            { owner => $user_obj->id(), resp_name => $resp_name })->first();
        $prj->delete();
        $self->redirect_to( $self->url_for('/app/home') );
    };

    get '/home/configure_resp' => sub {
        my $self = shift;
        my $resp_name = $self->param('name');
        my $user_obj = $self->stash('user_obj');
        my $prj = $db->resultset('Project')->search(
            { owner => $user_obj->id(), resp_name => $resp_name })->first();
        my $access_token = $self->get_user_oauth();
        my $branch_data = $self->oauth_request($access_token, "/repos/$resp_name/branches");
        my @b_names = map $_->{name}, @$branch_data;
        $self->stash('branch_names', \@b_names);
        $self->stash('prj', $prj);
        $self->render('app/home/configure_resp');
    };

    post '/home/do_resp_configuration' => sub {
        my $self = shift;
        my $resp_name = $self->param('name');
        my $main_lang = $self->param('main_lang');
        my $dev_branch = $self->param('dev_branch');

        my $user_obj = $self->stash('user_obj');
        my $prj = $db->resultset('Project')->search(
            { owner => $user_obj->id(), resp_name => $resp_name })->first();
        die "Not valid resp name"
            unless $prj;
        my $access_token = $self->get_user_oauth();
        my $branch_data = $self->oauth_request($access_token, "/repos/$resp_name/branches");

        if (defined $dev_branch) {
            die "Development branch not exists on Github?!"
                unless 1 == grep { $dev_branch eq $_->{name} } @$branch_data;
            $prj->dev_branch($dev_branch); 
        }
        else {
            $prj->dev_branch(undef);
        }
        die "Project language $main_lang not supported"
            unless grep { $main_lang eq $_ } qw{ en ja };
        $prj->main_lang($main_lang);
        #$prj->fetch_all_documention($access_token);
        $prj->fetch_lang_files($access_token);
        $prj->update();

        $self->redirect_to( $self->url_for('/app/home/configure_resp')->query(name => $prj->resp_name() ) );
    };

};

helper get_user_oauth => sub {
    my $self = shift;
    my $token = $self->stash('oauth_token');
    return $token if $token;
    my $user = $self->stash('user_obj');
    die "no user was defined" unless $user;
    my $oauth_obj = $self->oauth_obj();
    my $token_frozen = $user->oauth_token();
    $token = Net::OAuth2::AccessToken->session_thaw($token_frozen, profile => $oauth_obj);
    $self->stash('oauth_token' => $token);
    return $token;
};

helper oauth_obj => sub {
    my $self = shift;
    my $client = $self->stash('oauth_client');
    return $client if $client;
    require Net::OAuth2::Profile::WebServer;
    my $cb = 'http://localhost' . $self->url_for('/login/oauth_login');
    $client = Net::OAuth2::Profile::WebServer->new( 
        client_id     => $config->{github_key},
        client_secret => $config->{github_secret},
        site => 'https://github.com/',
        authorize_path => '/login/oauth/authorize',
        access_token_path => '/login/oauth/access_token',
        protected_resource_url => 'https://api.github.com/',
        scope => 'user,public_repo',
        token_scheme => 'auth-header:Bearer',
        redirect_uri  => $cb,
        auto_save => sub { 
            my ($profile, $token) = @_;
            my $user_obj = $self->stash('user_obj');
            return unless $user_obj;
            $user_obj->oauth_token($token);
            $user_obj->update();
        },
    );
    $self->stash('oauth_client' => $client);
    return $client;
};

helper oauth_request => sub {
    my $self = shift;
    my ($access_token, $url, $method) = @_;
    $method ||= 'get';
    my $res = $access_token->get($github_api . $url);
    if (!$res->is_success()) {
        die "failed to read user data from Github |$url|", $res->status_line, "|", $res->content, "|";
    }
    if (my $abort = $res->{_headers}{'client-aborted'}) {
        die "request $url from github failed: $abort";
    }
    my $content = $res->content;
    return decode_json($content);
};

app->start;

1;
