package LangCollab::Public;
use Mojo::Base 'Mojolicious::Controller';

sub index {
    my $self = shift;
    my $user = $self->stash('user_obj');
    if ($user) {
        return $self->redirect_to( $self->url_for('/app/home') );
    }
    $self->render;
};

sub logout {
    my $self = shift;
    $self->session( {user_id => 0, token => ''} );
    $self->session( expires => 1 );
    my $user = $self->stash('user_obj');
    if ($user) {
        $user->token('');
        $user->update();
    }
    $self->redirect_to( $self->url_for('/') );
}

1;
