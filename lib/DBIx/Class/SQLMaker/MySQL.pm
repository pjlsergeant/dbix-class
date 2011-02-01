package # Hide from PAUSE
  DBIx::Class::SQLMaker::MySQL;

use base qw( DBIx::Class::SQLMaker );

#
# MySQL does not understand the standard INSERT INTO $table DEFAULT VALUES
# Adjust SQL here instead
#
sub insert {
  my $self = shift;

  my $table = $_[0];
  $table = $self->_quote($table);

  if (! $_[1] or (ref $_[1] eq 'HASH' and !keys %{$_[1]} ) ) {
    return "INSERT INTO ${table} () VALUES ()"
  }

  return $self->SUPER::insert (@_);
}

# Allow STRAIGHT_JOIN's
sub _generate_join_clause {
    my ($self, $join_type) = @_;

    if( $join_type && $join_type =~ /^STRAIGHT\z/i ) {
        return ' STRAIGHT_JOIN '
    }

    return $self->SUPER::_generate_join_clause( $join_type );
}

# LOCK IN SHARE MODE
my $for_syntax = {
   update => 'FOR UPDATE',
   shared => 'LOCK IN SHARE MODE'
};

sub _lock_select {
   my ($self, $type) = @_;

   my $sql = $for_syntax->{$type}
    || $self->throw_exception("Unknown SELECT .. FOR type '$type' requested");

   return " $sql";
}

{
  my %part_map = (
    microsecond        => 'MICROSECOND',
    second             => 'SECOND',
    minute             => 'MINUTE',
    hour               => 'HOUR',
    day_of_month       => 'DAY',
    week               => 'WEEK',
    month              => 'MONTH',
    quarter            => 'QUARTER',
    year               => 'YEAR',
    # should we support these or what?
    second_microsecond => 'SECOND_MICROSECOND',
    minute_microsecond => 'MINUTE_MICROSECOND',
    minute_second      => 'MINUTE_SECOND',
    hour_microsecond   => 'HOUR_MICROSECOND',
    hour_second        => 'HOUR_SECOND',
    hour_minute        => 'HOUR_MINUTE',
    day_microsecond    => 'DAY_MICROSECOND',
    day_second         => 'DAY_SECOND',
    day_minute         => 'DAY_MINUTE',
    day_hour           => 'DAY_HOUR',
    year_month         => 'YEAR_MONTH',
  );

  my %diff_part_map = %part_map;
  $diff_part_map{day} = delete $diff_part_map{day_of_month};

  sub _datetime_sql { "EXTRACT($part_map{$_[1]} FROM $_[2])" }
  sub _datetime_diff_sql { "TIMESTAMPDIFF($diff_part_map{$_[1]}, $_[2], $_[3])" }
}

1;
