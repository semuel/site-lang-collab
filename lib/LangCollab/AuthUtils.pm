package LangCollab::AuthUtils;
use strict;
use warnings;
use JSON qw{decode_json};

require Exporter;
our @ISA = qw{Exporter};
our @EXPORT = qw{ get_oauth_obj do_oauth_request };

my $github_api = 'https://api.github.com';

sub get_oauth_obj {
    my $app = shift;
    my $client = $app->stash('oauth_client');
    return $client if $client;
    require Net::OAuth2::Profile::WebServer;
    my $callback_path = '/auth/callback';
    my $cb = $app->req->url->path($callback_path)->to_abs;
    $client = Net::OAuth2::Profile::WebServer->new( 
        client_id     => $app->config->{github_key},
        client_secret => $app->config->{github_secret},
        site => 'https://github.com/',
        authorize_path => '/login/oauth/authorize',
        access_token_path => '/login/oauth/access_token',
        protected_resource_url => 'https://api.github.com/',
        scope => 'user,public_repo',
        token_scheme => 'auth-header:Bearer',
        redirect_uri  => $cb,
        auto_save => sub { 
            my ($profile, $token) = @_;
            my $user_obj = $app->stash('user_obj');
            return unless $user_obj;
            $user_obj->oauth_token($token);
            $user_obj->update();
        },
    );
    $app->stash('oauth_client' => $client);
    return $client;
};

sub do_oauth_request {
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


1;
