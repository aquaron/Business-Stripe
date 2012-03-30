package Business::Stripe;

use strict;
use warnings;

use JSON;
use LWP::UserAgent;
use HTTP::Request::Common qw/DELETE GET POST/;
use MIME::Base64;

our $VERSION = '0.02';

use constant URL => 'https://api.stripe.com/v1/';

=head1 NAME

Business::Stripe - Interface for Stripe payment system.

=head1 SYNOPSIS

 my $stripe = Business::Stripe->new(
    -api_key => 'c6EiNIusHip8x5hkdIjtur7KNUA3TTpE'
 );

 $stripe->charges_create(
     amount => 400,
     card => 'tok_5EuIyKyCTc0f2V',
     description => 'Ice cream'
 ) and return $stripe->success;

 print $stripe->error->{message}, "\n";

=head1 DESCRIPTION

Provides common bindings for Stripe payment system.
Any API calls that do not have bindings can be access through the
generic C<api> method.

=head2 Methods

=head3 new (I<{options}>)

Requires C<-api_key> given to you as part of your Stripe account.
Optional C<-url> can override default:

 https://api.stripe.com/v1/

=cut

sub new {
	my $class = shift;
	my $self = { @_ };
	bless $self, $class;
	$self->_init;
	return $self;
}

=head3 api (I<method>,I<path>,I<params,...>)

Generic function that sends requests to Stripe.
Check Stripe API Reference L<https://stripe.com/docs/api> for specific calls.

Create a token:

 $stripe->api('post', 'tokens', 
     'card[number]' => '4242424242424242',
     'card[exp_month]' => 12,
     'card[exp_year]' => 2012,
     'card[cvc]' => 123,
     'currency' => 'usd'
 );

List charges:

 $stripe->api('get', 'charges', count => 5, offset => 0);

Delete coupon:

 $stripe->api('delete', 'coupons', '25OFF');

=head4 parameters

=over 4

=item method

One of C<post>, C<get>, or C<delete>.

=item path

Either C<charges>, C<events>, etc. Check API doc for complete list.

=item params

This optional set of parameters can be a single element or a list
of key/value pairs.

=back

All actions can be performed by using only this method.
The two set of functions C<charges> and C<customers> provided
in this package are made available for functions that are used frequently
in common implementations.

=cut

sub api {
	my $self = shift;
	my $method = shift;
	my $path = shift;
	my %params = (@_);

	if ($method eq 'post') {
		return $self->_compose($path, %params);
	} 

	$method eq 'delete' or undef $method;

	if (scalar @_ >= 2) {
		my $qs = join '&', 
			map { $_ . '=' . ($params{$_}||'') } keys %params;

		return $self->_compose($path.'?'.$qs, $method);
	} elsif (scalar @_) {
		return $self->_compose($path.'/'.$_[0], $method);
	}

	$self->_compose($path, $method);
}

=head3 error (I<void>)

Method returns C<0> when encounter error conditions.
The JSON object returned by Stripe can be retrieved via this method.

 print $stripe->error->{message}, "\n";

=cut

sub error {
	my $self = shift;
	return $self->{-error}->{error};
}

=head3 success (I<void>)

When calls are successful a positive value is returned
or if possible, the ID. Stripe's JSON object can be retrieved via
this method. Specific values are defined in the Stripe API Documentation.

 print $stripe->success->{data}->[0]->{description}, "\n";

=cut

sub success {
	my $self = shift;
	return $self->{-success};
}



=head2 Charges

Set of methods that handle credit/debit card such as charging a card,
refund, retrieve specifc charge and list charges.

=head3 charges_create (I<{params}>)

Charge the credit card.

=head4 parameters

Assumes currency in C<usd>. Uses token from Stripe.js.

 $stripe->charges(
    amount => 10,
    card => 'tok_Wzm6ewTBrkVvC3',
    description => 'customer@example.com'
 );

=over 4

=item amount

Positive integer larger than C<50> (amount is specified in cents).

=item currency

3-letter ISO code. Defaults to C<usd> (it's the only one supported).

=item customer

Required if not using C<card> below.
The C<ID> of an exisiting customer.

=item card

Required if not using C<customer> above.
Uses Token acquired from Stripe.js or give it the card details.

=item description (optional)

Descriptive text identifying the charge (recommend using customer's email).

=back

=head4 returns

Returns the C<id> if success (check C<success> for JSON object).
If error (use C<error> for JSON object) returns C<0>.

=cut

sub charges_create {
	my $self = shift;
	my %param = (@_);

	$param{currency} ||= 'usd';

	return $self->_compose('charges', %param);
}

=head3 charges_retrieve (I<id>)

Takes the charge C<id> value and yields data about the charge.

 $stripe->charges_retrieve('ch_uxLBSIZB8azrSr');

=cut

sub charges_retrieve {
	my ($self,$id) = (@_);
	return $self->_compose('charges/'.$id);
}

=head3 charges_refund (I<id>,[I<amount>])

Refund a specific C<amount> (or if omitted, full refund) to the charge C<id>.
C<amount> is in cents.

 ### refunds full amount
 $stripe->charges_refund('ch_uxLBSIZB8azrSr');

 ### refunds $5 over charge
 $stripe->charges_refund('ch_uxLBSIZB8azrSr', 500);

=cut

sub charges_refund {
	my ($self,$id,$amount) = (@_);

	return $self->_compose(
		'charges/'.$id.'/refund',
		$amount ? (amount => $amount) : []
	);
}

=head3 charges_list (I<{params}>)

List all the charges for a particular C<customer> or list everything.

 ### lists next 5 charges
 $stripe->charges_list(count => 5, offset => 1);

=head4 parameters

=over 4

=item count

Optional number of records to return.  Defaults to C<10>.

=item offset

Optional paging marker. Defaults to C<0>.

=item customer

Optional customer's ID for filtering.

 ### list top 10 charges for this customer
 $stripe->charges_list(customer => 'cus_gpj0mzwbQKBI7c');

=back

=cut

sub charges_list {
	my $self = shift;
	my %params = (@_);
	my $qs = join '&', map { $_ . '=' . ($params{$_}||'') } keys %params;

	return $self->_compose('charges?'.$qs);
}




=head2 Customers

Multiple charges associated to a customer. By creating a customer,
you don't have to ask for credit card information every charge.

=head3 customers_create (I<{params}>)

Creates a new customer according to the credit card information or token given.
Use this method to create a customer-ID for the given C<card>
(token when used in conjunction with Stripe.js).
The customer-ID can be passed to C<charges_create>'s C<customer> parameter
instead of C<card> so that you don't have to ask for credit card info again.

 ### creates the customer
 my $cid = $stripe->customers_create(
    card => 'tok_Wzm6ewTBrkVvC3',
    email => 'customer@example.com',
    description => 'userid-123456'
 );

 ### charges the customer $5
 $cid and $stripe->charges_create(
    customer => $cid,
    amount => 500,
    description => 'userid-123456 paid $5'
 );

=head4 options

=over 4

=item card

Can either be a token or credit card info.

=item coupon

Optional discount coupon code discount.

=item email

Optional customer's email.

=item description

Optional description.

=back

=head4 returns

Returns customer's ID if successful.

=cut

sub customers_create {
	my $self = shift;
	return $self->_compose('customers', @_);
}

=head3 customers_retrieve (I<id>)

Gets the customer's object.

 $stripe->customers_retrieve('cus_gpj0mzwbQKBI7c');

=cut

sub customers_retrieve {
	my ($self,$id) = (@_);
	return $self->_compose('customers/'.$id);
}

=head3 customers_update (I<id>,[I<{params}>])

Updates customer's information.

 $stripe->customers_update(
    customer => 'cus_gpj0mzwbQKBI7c',
    description => 'updated description'
 );

=cut

sub customers_update {
	my $self = shift;
	return $self->_compose('customers/'.(shift), @_);
}

=head3 customers_delete (I<id>)

Deletes the customer.

 $stripe->customers_delete('cus_gpj0mzwbQKBI7c');

=cut

sub customers_delete {
	my $self = shift;
	return $self->_compose('customers/'.(shift), 'delete');
}

=head3 customers_list (I<{params}>)

List all customers.

 $stripe->customers_list(count => 20);

=head4 parameters

=over 4

=item count

Optional number of records to return. Defaults to C<10>.

=item offset

Optional paging marker. Defaults to C<0>.

=back

=cut

sub customers_list {
	my $self = shift;
	my %params = (@_);
	my $qs = join '&', map { $_ . '=' . ($params{$_}||'') } keys %params;

	return $self->_compose('customers?'.$qs);
}




=head2 Helper Methods

=cut

sub _init {
	my $self = shift;

	$self->{-url}     ||= URL;
	$self->{-api_key} and
	$self->{-auth}      = 'Basic ' . encode_base64($self->{-api_key}) . ':';
}

=head3 _compose (I<resource>,[I<{params}>])

Helper function takes in a resource, defined by the Stripe API doc.
Current resources:

 charges
 coupons
 customers
 invoices
 invoiceitems
 plans
 tokens
 events

=cut

sub _compose {
	my $self = shift;
	my $resource = shift;

	return undef unless $self->{-auth};
	
	# reset
	undef $self->{-success};
	undef $self->{-error};

	my $ua = LWP::UserAgent->new;
	undef my $res;

	if (scalar @_ >= 2) {
		$res = $ua->request(
			POST $self->{-url} . $resource,
				Content => [ @_ ],
				Authorization => $self->{-auth}
		);
	} elsif (scalar @_ && $_[0] eq 'delete') {
		$res = $ua->request(
			DELETE $self->{-url} . $resource,
				Authorization => $self->{-auth}
		);
	} else {
		$res = $ua->request(
			GET $self->{-url} . $resource,
				Authorization => $self->{-auth}
		);
	}

	if ($res->is_success) {
		$self->{-success} = decode_json($res->content);
		return $self->{-success}->{id} || 1;
	}

	$self->{-error} = decode_json($res->content);
	return 0;
}

=head1 SEE ALSO

Stripe.js Documentation L<https://stripe.com/docs/stripe.js>.

Stripe Full API Reference L<https://stripe.com/docs/api>.

Full featured implementation by Luke Closs L<Net::Stripe>.

=head1 SINGLE FILE INSTALLATION

This module is implemented to as a single-file package.
If you don't want to use the CPAN distribution, you can download C<Stripe.pm>
from the root directory and renamed it to C<BusinessStripe.pm>:

 mv Stripe.pm BusinessStripe.pm

Edit C<BusinessStripe.pm> and remove the C<::> between the package name on
the first line to:

 package BusinessStripe;

Include the file in your program:

 use BusinessStripe;
 my $stripe = BusinessStripe->new(
     -api_key => 'c6EiNIusHip8x5hkdIjtur7KNUA3TTpE'
 );
 $stripe->charges_list;

=head1 HISTORY

=over 3

=item 20120327

v0.01 Initial release

=item 20120328

v0.02 Revised documentations, add README so tests won't fail.

=back

=head1 AUTHOR

Paul Pham (@phamnp)

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 Aquaron. All Rights Reserved.

This program and library is free software; 
you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
1;
