use utf8;
package LangCollab::Schema::Result::Readme;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LangCollab::Schema::Result::Readme

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<readmes>

=cut

__PACKAGE__->table("readmes");

=head1 ACCESSORS

=head2 prj_id

  data_type: 'integer'
  is_nullable: 0

=head2 lang

  data_type: 'char'
  is_nullable: 0
  size: 2

=head2 readme

  data_type: 'text'
  is_nullable: 0

=head2 format

  data_type: 'char'
  is_nullable: 1
  size: 5

=cut

__PACKAGE__->add_columns(
  "prj_id",
  { data_type => "integer", is_nullable => 0 },
  "lang",
  { data_type => "char", is_nullable => 0, size => 2 },
  "readme",
  { data_type => "text", is_nullable => 0 },
  "format",
  { data_type => "char", is_nullable => 1, size => 5 },
);

=head1 PRIMARY KEY

=over 4

=item * L</prj_id>

=item * L</lang>

=back

=cut

__PACKAGE__->set_primary_key("prj_id", "lang");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-02-04 14:59:29
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xS1mkiGeoS3hx01LCuX+JQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
