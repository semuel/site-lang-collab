#!/opt/local/bin/perl
use Mojolicious::Lite;
use FindBin;
use JSON qw{decode_json};
use lib $FindBin::Bin . '/lib';
use lib $FindBin::Bin . '/extlib';
use LangCollab::Schema;

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
    print STDERR "URL: |", $self->req->url->to_string, "|\n";
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
            $self->render(text => "Please login id($user_id) token($token)");
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
        $self->render('app/home');
    };

    get '/home/list_github_modules' => sub {
        my $self = shift;
        my $user_obj = $self->stash('user_obj');
        my $oauth_token = $user_obj->oauth_token();
    };

};

helper oauth_obj => sub {
    my $self = shift;
    require Net::OAuth2::Profile::WebServer;
    my $cb = 'http://localhost' . $self->url_for('/login/oauth_login');
    my $client = Net::OAuth2::Profile::WebServer->new( 
        client_id     => $config->{github_key},
        client_secret => $config->{github_secret},
        site => 'https://github.com/',
        authorize_path => '/login/oauth/authorize',
        access_token_path => '/login/oauth/access_token',
        protected_resource_url => 'https://api.github.com/',
        scope => 'user,public_repo',
        token_scheme => 'auth-header:Bearer',
        redirect_uri  => $cb,
    );
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
