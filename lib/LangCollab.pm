package LangCollab;
use Mojo::Base 'Mojolicious';

use LangCollab::Schema;

my $db;

sub db {
    return $db;
}

sub startup {
    my $self = shift;
    print STDERR "Started\n";

    $self->log->level('error');
    my $config = $self->plugin('Config');
    $self->secret( $config->{cookie_secret} );
    # $self->helper(users => sub { state $users = MyUsers->new });

    $db = LangCollab::Schema->connect(
        'dbi:mysql:dbname=' . $config->{database_table}, 
        $config->{database_user}, 
        $config->{database_password}
        );

    my $r = $self->routes;

    $r->get('/auth/authenticate')->to('auth#authenticate');
    $r->get('/auth/callback')->to('auth#callback');

    my $public = $r->bridge('/')->to('auth#maybe_user');
    $public->get('/')->to('public#index')->name('frontpage');
    $public->get('/logout')->to('public#logout');
    $public->get('/about')->to('public#about');

    my $app = $public->bridge('/app')->to('auth#must_user');
    $app->get('/home')->to('app#home')->name('apphome');
    $app->get('/user')->to('app#user');
    $app->post('/user/save')->to('app#user_save');
    $app->get('/github/list')->to('app#github_repos_list');
    $app->post('/plugin/register')->to('app#plugin_register');
    $app->get('/trans/plugin_list')->to('translations#plugin_list');

    my $plugin = $app->bridge('/plugin/:repos_user/:repos_name')->to('plugin#bridge_load');
    my $plugin_owner = $plugin->bridge('/')->to('plugin#owner_only');
    $plugin_owner->post('/save')->to('plugin#save');
    $plugin_owner->post('/delete')->to('plugin#delete');
    $plugin_owner->get('/edit')->to('plugin#edit');

    $self->helper( oauth_request => \&oauth_request_helper );
    $self->helper( db => sub { return $db } );

    # $r->any('/')->to('login#index')->name('index');
    # my $logged_in = $r->under->to('login#logged_in');
    # $logged_in->get('/protected')->to('login#protected');
    # $r->get('/logout')->to('login#logout');
}

sub oauth_request_helper {
    my $self = shift;
    my ($url, $method) = @_;
    $method ||= 'get';
    require LangCollab::AuthUtils;

    my $token = $self->stash('oauth_token');
    if (not defined $token) {
        my $user = $self->stash('user_obj');
        die "no user was defined" unless $user;
        my $oauth_obj = LangCollab::AuthUtils::get_oauth_obj($self);
        my $token_frozen = $user->oauth_token();
        $token = Net::OAuth2::AccessToken->session_thaw($token_frozen, profile => $oauth_obj);
        $self->stash('oauth_token' => $token);
    }
    return LangCollab::AuthUtils::do_oauth_request($token, $url, $method);
};

1;