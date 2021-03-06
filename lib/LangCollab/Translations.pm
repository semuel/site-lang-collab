package LangCollab::Translations;
use Mojo::Base 'Mojolicious::Controller';

# Status codes:
# the original translation that comes from the project
use constant STATUS_ORIG => 1; 
# accepted translation from user
use constant STATUS_ACCEPTED => 2; 
# submition from user, waiting to be reviewed
use constant STATUS_WAITING => 3; 
# some other translationg was accepted
use constant STATUS_NOT_ACCEPTED => 4;
# rejected translation
use constant STATUS_REJECTED => 5; 
# suspected SPAM
use constant STATUS_MAYBESPAM => 9; 
# marked spam
use constant STATUS_SPAM => 10; 

sub trans_list {
    my $self = shift;
    my $prj = $self->stash('prj_obj');
    my $user_obj = $self->stash('user_obj');
    my $is_owner = ( $prj->owner() == $user_obj->id() );
    my @trans = $self->db->resultset('Translation')->search({ prj_id => $prj->id() })->all();

    # each record has the following fields:
    # {
    #     has_waiting => 1,
    #     source_lang => 'en',
    #     source_text => 'Some translated text',
    #     translations => [ array of translation objects ],
    # }

    my $trans_array = [];
    my $trans_hash = {};
    my $waiting_langs = {};
    my $waiting_array = [];
    my $langs_source = {};

    foreach my $t (@trans) {
        my $src = $t->source();
        my $rec = $trans_hash->{$src};
        if (not $rec) {
            $rec = {
                has_waiting => 0,
                source_lang => $prj->main_lang(),
                source_text => $src,
                translations => [],
            };
            $trans_hash->{$src} = $rec;
            push @$trans_array, $rec;
        }
        push @{ $rec->{translations} }, $t;
        if ($t->status() == STATUS_WAITING) {
            if ($rec->{has_waiting} == 0) {
                push @$waiting_array, $rec;
                $rec->{has_waiting} = 1;
            }
            $waiting_langs->{ $t->lang() } = 1;
        }
    }

    foreach my $rec (@$trans_array) {
        my @originals = grep { $_->status() == STATUS_ORIG } @{ $rec->{translations} };
        foreach my $orig (@originals) {
            push @{ $langs_source->{ $orig->lang() } }, $orig;
        }
    }
    my @have_langs = grep { exists $langs_source->{$_} } qw{en ja};

    $self->stash('trans_array', $trans_array);
    $self->stash('trans_hash', $trans_hash);
    $self->stash('waiting_langs', $waiting_langs);
    $self->stash('waiting_array', $waiting_array);
    $self->stash('langs_source', $langs_source);
    $self->stash('have_langs', \@have_langs);
    return $self->render('app/trans_list');
}

1;
