#!/opt/local/bin/perl
use Mojolicious::Lite;
use FindBin;
use lib $FindBin::Bin . '/extlib';

my $config = plugin 'Config';

app->secret( $config->{cookie_secret} );

get '/' => sub {
    my $self = shift;
    print STDERR "URL: |", $self->req->url->to_string, "|\n";
    $self->render('index');
};

get '/app/oauth_start' => sub {
    my $self = shift;
    return $self->redirect_to( $self->oauth_obj->authorize );
};

get '/app/oauth_login' => sub {
    my $self = shift;
};

helper oauth_obj => sub {
    my $self = shift;
    require Net::OAuth2::Profile::WebServer;
    my $cb = 'http://localhost' . $self->url_for('/app/oauth_login');
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
