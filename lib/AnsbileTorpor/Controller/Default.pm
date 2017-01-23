use 5.22.0;

package AnsbileTorpor::Controller::Default;
use Mojo::Base 'Mojolicious::Controller';

=head2 index

Render the main page

=cut

sub index {
  my $self = shift;

  $self->reply->static('help.txt');
}

1;
