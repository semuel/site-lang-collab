#!/opt/local/bin/perl
use Mojolicious::Lite;
use FindBin;
use JSON;
use Storable;
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
    my $res = $token->get('/user');
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
    my $oauth_token = freeze($access_token->session_freeze());
    $self->session({ user_id => $user_id, token => $token });
    $self->session(expiration => 604800);
    $self->redirect_to( $self->url_for('/app/home') );
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
