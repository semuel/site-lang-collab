package LangCollab::Auth;
use Mojo::Base 'Mojolicious::Controller';
use LangCollab::AuthUtils;

my @token_chars = ('a'..'z', 'A'..'Z', '0'..'9');

sub maybe_user {
    my $self = shift;
    my $user_id = $self->session->{user_id};
    my $token = $self->session->{token};
    if (not $user_id or not $token) {
        return 1;
    }
    my $user = $self->db->resultset('User')->find($user_id);
    if (not $user or $token ne $user->token()) {
        return 1;
    }
    $self->stash(user_obj => $user);
    $self->stash(user_data => $user->user_data());
    return 1;
}

sub must_user {
    my $self = shift;
    my $user_obj = $self->stash('user_obj');
    if (not $user_obj) {
        my $is_xhr = ( $self->param('xhr') or ( ( $self->stash('format') || '' ) eq 'json' ) );
        if ($is_xhr) {
            $self->render()
        }
        else {
            $self->flash(user_msg => { lvl => 'error', text => 'Login expired - please login again' });
            $self->redirect_to( $self->url_for('frontpage') );
        }
        return undef;
    }
    return 1;
}

sub authenticate {
    my $self = shift;
    my $oauth_obj = get_oauth_obj($self);
    return $self->redirect_to( $oauth_obj->authorize );
}

sub callback {
    my $self = shift;
    my $code = $self->param('code');
    my $oauth_obj = get_oauth_obj($self);
    my $access_token = $oauth_obj->get_access_token($code);
    my $data = do_oauth_request($access_token, '/user');
    my $user_id = $data->{id};
    my $token = join '', map { $token_chars[int(rand(scalar(@token_chars)))] } 1..20;
    my $update_user = sub {
        my $user_data = shift;
        foreach my $key (qw{url name email}) {
            $user_data->{$key} = $data->{$key};
        }
        return $user_data;
    };
    my $user_class = $self->app->db->resultset('User');
    my $user_obj = $user_class->find($user_id);
    my $is_new_user;
    if ($user_obj) {
        $is_new_user = 0;
        $user_obj->oauth_token($access_token);
        $user_obj->user_data( $update_user->( $user_obj->user_data() ) );
        $user_obj->token($token);
        $user_obj->update();
    }
    else {
        $is_new_user = 1;
        $user_obj = $user_class->new({ id => $user_id, token => $token });
        $user_obj->oauth_token($access_token);
        $user_obj->user_data( $update_user->( { } ) );
        $user_obj->insert();
    }
    $self->session({ user_id => $user_id, token => $token });
    $self->session(expiration => 604800);
    $self->redirect_to( $self->url_for( $is_new_user ? '/app/user' : '/app/home' ) );
}

1;
