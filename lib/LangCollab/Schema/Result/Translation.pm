use utf8;
package LangCollab::Schema::Result::Translation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LangCollab::Schema::Result::Translation

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<translations>

=cut

__PACKAGE__->table("translations");

=head1 ACCESSORS

=head2 trans_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 prj_id

  data_type: 'integer'
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  is_nullable: 0

=head2 status

  data_type: 'integer'
  is_nullable: 0

=head2 lang

  data_type: 'char'
  is_nullable: 0
  size: 2

=head2 source

  data_type: 'varchar'
  is_nullable: 0
  size: 400

=head2 trans

  data_type: 'varchar'
  is_nullable: 0
  size: 400

=head2 source_quotes

  data_type: 'char'
  is_nullable: 0
  size: 4

=head2 dest_quotes

  data_type: 'char'
  is_nullable: 0
  size: 4

=cut

__PACKAGE__->add_columns(
  "trans_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "prj_id",
  { data_type => "integer", is_nullable => 0 },
  "user_id",
  { data_type => "integer", is_nullable => 0 },
  "status",
  { data_type => "integer", is_nullable => 0 },
  "lang",
  { data_type => "char", is_nullable => 0, size => 2 },
  "source",
  { data_type => "varchar", is_nullable => 0, size => 400 },
  "trans",
  { data_type => "varchar", is_nullable => 0, size => 400 },
  "source_quotes",
  { data_type => "char", is_nullable => 0, size => 4 },
  "dest_quotes",
  { data_type => "char", is_nullable => 0, size => 4 },
);

=head1 PRIMARY KEY

=over 4

=item * L</trans_id>

=back

=cut

__PACKAGE__->set_primary_key("trans_id");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-03-31 00:12:12
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:w+Yva7gWLWu4QUXKJZzUBQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
