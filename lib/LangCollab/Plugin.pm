package LangCollab::Plugin;
use Mojo::Base 'Mojolicious::Controller';

sub bridge_load {
    my $self = shift;
    my $repos_user = $self->stash('repos_user');
    my $repos_name = $self->stash('repos_name');

    my $respo_full = "$repos_user/$repos_name";

    my $prj = $self->db->resultset('Project')->search({ resp_name => $respo_full })->first();
    if (not $prj) {
        $self->flash(user_msg => { lvl => 'error', text => 'Not valid plugin name' });
        return $self->redirect_to( $self->url_for('/app/home') );
    }
    $self->stash('prj_obj', $prj);
    return 1;
}

sub owner_only {
    my $self = shift;
    my $prj = $self->stash('prj_obj');
    my $user_obj = $self->stash('user_obj');
    return 1 if $prj->owner() == $user_obj->id();
    $self->flash(user_msg => { lvl => 'error', 
        text => 'You don\'t have the permission to edit plugin '.$prj->resp_name() });
    return $self->redirect_to( $self->url_for('/app/home') );
}

sub save {
    my $self = shift;
    my $main_lang = $self->param('main_lang');
    my $dev_branch = $self->param('dev_branch');

    my $prj = $self->stash('prj_obj');
    my $resp_name = $prj->resp_name();

    my $branch_data = $self->oauth_request("/repos/$resp_name/branches");

    if (1 == @$branch_data) {
        $prj->dev_branch($branch_data->[0]->{name});
    }
    elsif (defined $dev_branch) {
        unless (1 == grep { $dev_branch eq $_->{name} } @$branch_data) {
            my $msg = "Development branch $dev_branch not exists on Github?!";
            $self->flash(user_msg => { lvl => 'error', text => $msg });
            return $self->redirect_to( $self->url_for('/app/plugin')->query(name => $prj->resp_name() ) );
        }
        $prj->dev_branch($dev_branch); 
    }
    unless (grep { $main_lang eq $_ } qw{ en ja }) {
        my $msg = "Project language $main_lang not supported";
        $self->flash(user_msg => { lvl => 'error', text => $msg });
        return $self->redirect_to( $self->url_for('/app/plugin')->query(name => $prj->resp_name() ) );
    }
    $prj->main_lang($main_lang);
    #$prj->fetch_all_documention($access_token);
    my $error;
    my $access_token = $self->stash('oauth_token');
    $prj->fetch_lang_files($access_token, \$error);
    if ($error) {
        my $msg = "Error: $error";
        $self->flash(user_msg => { lvl => 'error', text => $msg });
        return $self->redirect_to( $self->url_for('/app/plugin')->query(name => $prj->resp_name() ) );
    }
    $prj->update();

    my $msg = "Plugin " . $prj->short_name() . " saved";
    $self->flash(user_msg => { lvl => 'success', text => $msg });
    return $self->redirect_to( $self->url_for('/app/home') );
}

sub delete {
    my $self = shift;
    my $prj = $self->stash('prj_obj');
    $prj->delete();
    my $msg = 'Plugin ' . $prj->short_name() . ' was deleted';
    $self->flash(user_msg => { lvl => 'info', text => $msg });
    $self->redirect_to( $self->url_for('/app/home') );
};

sub edit {
    my $self = shift;
    my $user_obj = $self->stash('user_obj');
    my $prj = $self->stash('prj_obj');
    my $resp_name = $prj->resp_name();
    my $branch_data = $self->oauth_request("/repos/$resp_name/branches");
    my @b_names = map $_->{name}, @$branch_data;
    $self->stash('branch_names', \@b_names);
    $self->stash('prj', $prj);
    $self->render('app/plugin');
}

1;
