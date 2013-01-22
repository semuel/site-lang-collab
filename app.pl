#!/opt/local/bin/perl
use Mojolicious::Lite;
use FindBin;
use JSON;
use lib $FindBin::Bin . '/lib';
use lib $FindBin::Bin . '/extlib';
use LangCollab::Schema;

my $config = plugin 'Config';

app->secret( $config->{cookie_secret} );
my @token_chars = ('a'..'z', 'A'..'Z', '0'..'9');

has schema => sub {
  return LangCollab::Schema->connect(
    'dbi:mysql:dbname=' . $config->{database_table}, 
    $config->{database_user}, 
    $config->{database_password}
    );
};

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
    my $res = $access_token->get('/user');
    if (!$res->is_success()) {
        die "failed to read user data from Github";
    }
    if (my $abort = $res->{_headers}{'client-aborted'}) {
        die "request from github failed: $abort";
    }
    my $content = $res->content;
    my $data = JSON::decode_json($content);
    my $user_id = $data->{id};
    my $token = map { int(rand(scalar(@token_chars))) } 1..20;
    my $user_data = { };
    foreach my $key (qw{url name email}) {
        $user_data->{$key} = $data->{$key};
    }
    my $user_class = $self->schema->resultset('User');
    my $user_obj = $user_class->find($user_id);
    if ($user_obj) {
        $user_obj->oauth_token($access_token);
        $user_obj->user_data($user_data);
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
        my $user_id = $self->session->{id};
        my $token = $self->session->{token};
        if (not $user_id or not $token) {
            $self->render(text => 'Please login');
            return;
        }
        my $user = $self->schema->resultset('User')->find($user_id);
        if (not $user or $token ne $user->token()) {
            $self->render(text => 'Please login');
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
        redirect_uri  => $cb,
    );
    return $client;
};

app->start;

1;
