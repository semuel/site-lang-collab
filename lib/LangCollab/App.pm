package LangCollab::App;
use Mojo::Base 'Mojolicious::Controller';

sub home {
    my $self = shift;
    my $user_obj = $self->stash('user_obj');
    my @prjs = $self->db->resultset('Project')->search({ owner => $user_obj->id() })->all();
    $self->stash('self_prjs' => \@prjs);
    $self->render('app/home');
}

sub user {
    my $self = shift;
    my $user_obj = $self->stash('user_obj');
    my $user_data = $user_obj->user_data();
    my $langs = $user_data->{languages};
    if (not defined $langs) {
        $langs = { qw{ en 0 ja 0 de 0 es 0 fr 0 } };
    }
    my $official_name = { qw{ en English ja Japanese de German es Spanish fr Franch } };
    my @lang_list;
    foreach my $ln (qw{ en ja de es fr }) {
        push @lang_list, { 
            name => $ln, 
            value => $langs->{$ln}, 
            fullname => $official_name->{$ln},
        };
    }
    $self->stash('lang_list', \@lang_list);

    $self->render('app/user');
};

sub user_save {
    my $self = shift;
    my $user_obj = $self->stash('user_obj');
    my $user_data = $user_obj->user_data();
    my $langs = $user_data->{languages};
    if (not defined $langs) {
        $langs = { qw{ en 0 ja 0 de 0 es 0 fr 0 } };
    }
    foreach my $ln (keys %$langs) {
        $langs->{$ln} = 0 + $self->param($ln);
    }
    $user_data->{languages} = $langs;
    $user_obj->user_data($user_data);
    $user_obj->update;
    my $redirect;
    if (grep { $_ > 0 } values %$langs) {
        $self->flash(user_msg => { lvl => 'success', text => 'User setting saved' });
        $redirect = $self->url_for('/app/home');
    }
    else {
        $self->flash(user_msg => { lvl => 'error', text => 'Surely you know one language?!' });
        $redirect = $self->url_for('/app/user');
    }
    return $self->redirect_to( $redirect );
};

sub github_repos_list {
    my $self = shift;
    my $user_obj = $self->stash('user_obj');
    my @prjs = $self->db->resultset('Project')->search({ owner => $user_obj->id() })->all();
    my %existing = map { ( $_->resp_name() => 1 ) } @prjs;
    my $data = $self->oauth_request('/user/repos?type=owner');
    my @resps;
    foreach my $rec (@$data) {
        next if exists $existing{ $rec->{full_name} };
        push @resps, { 
            fullname => $rec->{full_name},
            description => $rec->{description},
            short => $rec->{name},
        };
    }
    $self->stash('resp_data', \@resps);
    $self->render('app/github_list');
}

sub plugin_register {
    my $self = shift;
    # name is in the format of owner/resp_name
    my $resp_name = $self->param('name');
    my $resp_data = $self->oauth_request("/repos/$resp_name");
    my $branch_data = $self->oauth_request("/repos/$resp_name/branches");
    my $prj = $self->db->resultset('Project')->new({
        url => $resp_data->{html_url},
        owner => $self->stash('user_obj')->id(),
        resp_name => $resp_name,
        description => $resp_data->{description},
        master_branch => $resp_data->{master_branch},
        dev_branch => $resp_data->{master_branch},
        });
    $prj->insert();
    my $error;
    my $access_token = $self->stash('oauth_token');
    $prj->fetch_lang_files($access_token, \$error);
    if ($error) {
        my $msg = 'Error while registering plugin ' . $prj->short_name() . ': ' . $error;
        $self->flash(user_msg => { lvl => 'error', text => $msg  });
        $prj->delete();
        return $self->redirect_to( $self->url_for('/app/github/list') );
    }
    if (@$branch_data > 1) {
        $self->flash(user_msg => { lvl => 'info', text => 'Please choose your active dev branch' });
    }
    return $self->redirect_to( $self->url_for("/app/plugin/$resp_name/edit") );
}

1;
