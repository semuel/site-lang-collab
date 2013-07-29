use utf8;
package LangCollab::Schema::Result::Project;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LangCollab::Schema::Result::Project

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<project>

=cut

__PACKAGE__->table("project");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 url

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 owner

  data_type: 'integer'
  is_nullable: 0

=head2 resp_name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 description

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 master_branch

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 dev_branch

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 main_lang

  data_type: 'char'
  is_nullable: 0
  size: 2

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "url",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "owner",
  { data_type => "integer", is_nullable => 0 },
  "resp_name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "master_branch",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "dev_branch",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "main_lang",
  { data_type => "char", is_nullable => 0, size => 2 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-02-04 14:59:28
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:kjNJictD4WtbaGcODgVbOA


# You can replace this text with custom code or comments, and it will be preserved on regeneration

use WWW::Github::Files;
use Carp;

sub detect_file_lang {
    my $content = shift;
    my $size = length $content;
    my $en =()= $content =~ m/([a-zA-Z])/g;
    return ($en < $size * 0.4 ? 'ja' : 'en');
}

sub fetch_all_documention {
    my ($self, $token) = @_;
    my ($author, $resp) = split '/', $self->resp_name(), 2;
    my $master = WWW::Github::Files->new(   
        author => $author,
        resp => $resp,
        branch => 'master',
    );
    my @files = $master->open('/')->readdir();
    foreach my $file (@files) {
        next unless $file->is_file();
        my $name = $file->{name};
        next unless $name =~ m/^README/;
        my $content = $file->read();
        my $lang = 
              $name =~ m/\bja\b/ ? 'ja'
            : $name =~ m/\ben\b/ ? 'en'
            : detect_file_lang($content);
        print STDERR "Found file |$name|$lang|\n";
    }
}

sub fetch_lang_files {
    my ($self, $token, $error) = @_;
    my ($author, $resp) = split '/', $self->resp_name(), 2;
    my $master = WWW::Github::Files->new(   
        author => $author,
        resp => $resp,
        branch => $self->dev_branch() || $self->master_branch(),
    );
    my @plugins = $master->open('/plugins')->readdir();
    if (@plugins != 1) {
        $$error = 'Can only handle one plugin per git';
        return;
    }
    my $plugin_dir = $plugins[0];
    my $config = $master->open($plugin_dir->path().'/config.yaml')->read();
    my ($l10n_class) = $config =~ m/^l10n_class:\s*(.*)$/m;
    if (not $l10n_class) {
        $$error = 'This plugin does not have a l10n_class defined';
        return;
    }
    $l10n_class =~ s/::/\//g;
    my $lang_path = $plugin_dir->path().'/lib/'.$l10n_class;
    my @lang_files = $master->open($lang_path)->readdir();

    require LangCollab::ParseLangFile;
    my $cleaner = \&LangCollab::ParseLangFile::get_str_inter;
    my $tr_class = $::db->resultset('Translation');

    foreach my $file_obj (@lang_files) {
        my $lang_name = lc( substr( $_->name(), 0, 2 ) );
        my $content = Encode::decode( "UTF8", $file_obj->read());
        my $tokens = LangCollab::ParseLangFile->parse($content);
        # each token is ['type', value, begin_sep, end_sep]
        my @strs = grep { $_->[0] eq 'STR' } @$tokens;
        next unless scalar( @strs ) % 2 == 0;
        my %hash;
        while (my $key_rec = shift @strs) {
            my $value_rec = shift @strs;
            my $key = $cleaner->($key_rec);
            $hash{$key} = [$key_rec, $value_rec];
        }
        my $iter = $tr_class->search({
            prj_id => $self->id(),
            user_id => $self->owner(),
            status => 1, 
            lang => $lang_name,
        });
        while (my $tr = $iter->next()) {
            if (exists $hash{$tr->source()}) {
                $tr->
            }
        }
            # my $tr = $tr_class->new(
            #     prj_id => $self->id(),
            #     user_id => $self->owner(),
            #     status => 1, 
            #     lang => $lang_name,
            #     source => $cleaner->($key_rec),
            #     trans => $cleaner->($value_rec),
            #     source_quotes => $key_rec->[2],
            #     dest_quotes => $value_rec->[2],
            # );
            # $tr->insert();
    }
    print STDERR "Files: |", join('|', map { $_->name() } @lang_files), "|\n";
}

sub short_name {
    my $self = shift;
    my ($user, $sname) = split '/', $self->resp_name(), 2;
    return $sname;
}

1;
