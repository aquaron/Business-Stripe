package Business::Stripe;

use strict;
use warnings;

use JSON;
use LWP::UserAgent;
use HTTP::Request::Common qw/DELETE GET POST/;
use MIME::Base64 qw(encode_base64);

our $VERSION         = '0.07';

use constant URL     => 'https://api.stripe.com/v1/';

=encoding utf8

=head1 NAME

Business::Stripe - Interface for Stripe payment system.

=head1 SYNOPSIS

 my $stripe = Business::Stripe->new(
    -api_key => 'your-api-key-here',
 );

 ## get the payment token from Stripe.js, then:
 $stripe->charges_create(
     amount         => 400,
     source         => 'tok_5EuIyKyCTc0f2V',
     description    => 'Ice cream'
 ) and return $stripe->success;

 say $stripe->error->{message};

=head1 DESCRIPTION

This module provides common bindings for the Stripe payment system.
Any API calls that do not have bindings can be accessed through the
generic C<api> method.

=head2 General Methods

=head3 new (I<%options>)

Creates a new Business::Stripe object for you to use. The only
B<< required argument >> is C<-api_key>, which was given to you
as part of your Stripe account to access the API.

Other (optional) arguments are:

=over 4

=item C<-version> Sets a Stripe API version to use, overriding your
account's default. You can use this to test if new versions of
the API work with your code. To support marketplaces, for instance, you
should use at least C<'2014-11-05'>.

=item C<-ua_args> Hashref of options that will be passed directly as
arguments to LWP::UserAgent. Example:

    my $stripe = Business::Stripe->new(
        -api_key => 'xxxxxxxxx',
        -ua_args => {
            timeout   => 10,
            env_proxy => 1,
            agent     => 'myApp',
            ssl_opts  => { verify_hostname => 0 },
        },
    );

=item C<-ua> Completely overrides the default user agent object (L<LWP::UserAgent>).
Note that your object I<must> accept HTTPS, and provide a C<request()> method
accepting L<HTTP::Request> objects and returning L<HTTP::Response>-compatible
objects. You can use this to have a common user agent make all requests in
your code. The example above works exactly like:

    my $ua = LWP::UserAgent->new(
        timeout   => 10,
        env_proxy => 1,
        agent     => 'myApp',
        ssl_opts  => { verify_hostname => 0 },
    );

    my $stripe = Business::Stripe->new(
        -api_key => 'xxxxxxxx',
        -ua      => $ua,
    );

=item C<-url> Overrides the default API endpoint (C<https://api.stripe.com/v1/>)

=item C<-stripe_account> If you use the
L<< OAauth authentication flow for managed accounts|https://stripe.com/docs/connect/authentication >>
You can use this argument to make operations on behalf of a managed account.

=back

=cut

sub new {
    my $class    = shift;
    my $self     = { @_ };

    bless $self, $class;
    $self->_init;
    return $self;
}

=head3 api (I<$method>, I<$path>, I<%params>)

Generic function that sends requests to Stripe.
Check the L<< Stripe API Reference|https://stripe.com/docs/api >>
for specific calls.

The first argument is the HTTP method: C<"post">, C<"get"> or C<"delete">.

The second is the target path, like "tokens", "plans", "customers"
or even complex paths like "customers/$id/subscriptions". Check the
Stripe API Reference for a list of all available paths.

Use the optional third argument to send a hash of data with your API call.
This is usually required on all C<"post"> calls to the API.

On success, it returns a true value. If the returned data structure contains
an C<id> field, this is the value returned. Otherwise, "1" is returned and
you should check L<< $stripe->success() | /success >> for the actual data
structure.

In case of failures, it returns false (0) and you should then check
L<< $stripe->error() | /error >> for the appropriate data structure.

Examples:

=over 4

=item get a credit card source token on the server side (without using Stripe.js)

    my $token_id = $stripe->api('post', 'tokens',
        'card[number]'    => '4242424242424242',
        'card[exp_month]' => 12,
        'card[exp_year]'  => 2022,
        'card[cvc]'       => 123
    ) or die $stripe->error->{message};

=item create a new customer (with the $token_id from above)

    my $customer = $stripe->api('post', 'customers',
        email       => 'myuser@example.com',
        name        => 'Jane S. Customer',
        description => 'Displayed alongside the customer on your dashboard',
        source      => $token_id,
    ) and $stripe->success;
    die $stripe->error unless $customer;

=item create a new plan to subscribe your customers

    my $plan_id = $stripe->api('post', 'plans',
        'amount'        => 999,       # *IN CENTS* (999 = 9.99). Use 0 for a free plan!
        'id'            => 'my-plan', # Optional. Must be unique in your account
        'currency'      => 'usd',     # See https://stripe.com/docs/currencies
        'interval'      => 'month',   # Also: 'day', 'week', 'year'
        'product[name]' => 'My Plan',
    ) or die $stripe->error->{message};

=item subscribe the customer to a plan (using examples above)

    my $subscription = $stripe->api('post', 'subscriptions',
        'customer'       => $customer->{id},
        'items[0][plan]' => $plan_id,
    ) ? $stripe->success : $stripe_error;

=item cancel a subscription immediately

 $stripe->api('delete', "subscriptions/" . $subscription->{id})
    or die "error canceling subscription: " . $stripe->error->{message};

=back

As you can see, all actions can be performed by using only this method.
The other methods provided by this class are just helper wrappers around this,
for frequently made calls.

=cut

sub api {
    my $self        = shift;
    my $method      = shift;
    my $path        = shift;

    if ($method eq 'post') {
        return $self->_compose($path, @_);
    }

    $method eq 'delete' or undef $method;

    if (scalar @_ >= 2) {
        my %params      = (@_);
        my $qs     = join '&', map {
            $_ . '=' . ($params{$_}||'')
        } sort keys %params;

        return $self->_compose($path.'?'.$qs, $method);
    } elsif (scalar @_) {
        ### allowing api('delete','plans','gold')
        ### for readability api('delete','plans/gold');
        return $self->_compose($path.'/'.$_[0], $method);
    }

    $self->_compose($path, $method);
}

=head3 error

All API and helper methods return C<0> when they encounter error conditions.
The JSON object returned by Stripe can be retrieved via this method.

 say $stripe->error->{message};

Most error messages include C<message>, C<code>, C<type> and C<doc_url>.

=cut

sub error {
    return shift->{-error}->{error};
}

=head3 success

All API and helper methods return either C<1> or the object's ID on success.
Use this method to get access to the complete JSON object returned on the
last call made by your object. See Stripe's API Documentation for details
on what is returned on each call.

 say $stripe->success->{data}->[0]->{description};

=cut

sub success {
    return shift->{-success};
}

=head2 Charges

Set of methods that handle credit/debit card such as charging a card,
refund, retrieve specific charge and list charges.

B<Note:> Charges will likely fail for new cards added if the new SCA
applies. The flow should be switched to payment_intents (see below).
Existing payment methods should continue to work.

=head3 charges_create (I<%params>)

    my $success = $stripe->charges_create(
        amount      => 100,  # <-- amount in cents
        source      => 'tok_Wzm6ewTBrkVvC3',
        description => 'customer@example.com'
    );

Charges a credit card or other payment sources. This is exactly
the same as C<< $stripe->api('post', 'charges', %params) >>,
except that it defaults to 'usd' if you don't provide a currency.

It returns the C<id> of the charge on success, or 0 on error.
You may also check L<< $stripe->success | /success >> or
L<< $stripe->error | /error >> for the complete JSON.

Please see Stripe's API Documentation for which parameters are
accepted by your current API version.

B<Note:> The C<amount> field is in the I<< currency's smallest unit >>.
For currencies that allow cents (like USD), an amount of 100 means $1.00,
1000 mean $10.00 and so on. For zero-decimal currencies (like JPY) you don't
have to multiply, as an amount of 100 mean ¥100.

B<Note:> Older (2015-ish) versions of Stripe's API support the C<card>
parameter containing the source token from Stripe.js. This has since
been deprecated in favour of the C<source> parameter, shown in the
example above.

=cut

sub charges_create {
    my $self             = shift;
    my %param            = (@_);
    $param{currency}   ||= 'usd';

    return $self->_compose('charges', %param);
}

=head3 charges_retrieve (I<$id>)

    my $charge_data = $stripe->charges_retrieve('ch_uxLBSIZB8azrSr')
        and $stripe->success;

Takes the charge C<id> value and yields data about the charge, available
on L<< $stripe->success | /success >>.

This is exactly the same as C<< $stripe->api('get', "charges/$charge_id") >>.

=cut

sub charges_retrieve {
    my $self        = shift;
    my $id          = shift;
    return $self->_compose('charges/'.$id);
}

=head3 charges_refund (I<$id>, [I<$amount>])

Refunds a specific C<amount> (or if omitted, issues a full refund)
to the charge C<id>. Remember: the C<amount> parameter is I<in cents>
whenever the currency supports cents.

 ### refunds full amount
 $stripe->charges_refund('ch_uxLBSIZB8azrSr')
    or die $stripe->error->{message};

 ### refunds $5 over a bigger charge
 $stripe->charges_refund('ch_uxLBSIZB8azrSr', 500)
    or die $stripe->error->{message};

=cut

sub charges_refund {
	my ($self,$id,$amount) = (@_);

	return $self->_compose(
		'charges/'.$id.'/refunds',
		$amount ? (amount => $amount) : []
	);
}

=head3 charges_list (I<%params>)

List all the charges, with pagination.

    ### lists next 5 charges
    my $charges = $stripe->charges_list(limit => 5)
        ? $stripe->success : die $stripe->error->{message};

    foreach my $charge (@{$charges->{data}}) {
        say $charge->{amount} . $charge->{currency};
    }

    if ($charges->{has_more}) {
        say "there are more charges to show if you raise the limit"
          . " or change the 'starting_after' argument.";
    }

Pass on the customer's ID to only get charges made to that customer:

    $stripe->charges_list(customer => 'cus_gpj0mzwbQKBI7c')
        or die "error fetching customer charges: " . $stripe->error;

    my $charges = $stripe->success;

=cut

sub charges_list {
    my $self        = shift;
    my %params      = (@_);
    my $qs          = join '&', map {
        $_ . '=' . ($params{$_}||'')
    } sort keys %params;

    return $self->_compose('charges' . ($qs ? "?$qs" : ''));
}


=head2 Payment Intents

Set of methods that handle colling payments from a customer. These help build
a payment flow, including possible authentication steps that may be required.

Payment intents are superceding the charges api for new SCA regulations.

If this is an off session payment, it may be helpful to create a setup intent
first on a website (using stripe.js), see below.

=head3 payment_intents_create (I<%params>)

    my $success = $stripe->payment_intents_create(
        customer        => '<customer_id>',
        description     => 'A payment intent',
        amount          => '40',
    );

Creates a payment intent. You will need to attach a payment method now, or later
when confirming the intent (see confirm below). 

C<< confirm => 'true' >> will create and confirm the intent all in the same call.

C<amount> is required

C<currency> is required, but will default to usd in this module.

=cut

sub payment_intents_create {
    my $self             = shift;
    my %param            = (@_);
    $param{currency}   ||= 'usd';

    return $self->_compose('payment_intents', %param);
}

=head3 payment_intents_retrieve (I<$id>)

    my $payment_intents_data = $stripe->payment_intents_retrieve('pi_xxxx')
        and $stripe->success;

=cut

sub payment_intents_retrieve {
    my $self        = shift;
    my $id          = shift;
    return $self->_compose('payment_intents/'.$id);
}


=head3 payment_intents_update (I<%params>)

    my $success = $stripe->payment_intents_update( $payment_intents_id, 
        'description' => 'An updated payments intent' );	

Takes the payment intent value and update it with some new information

=cut

sub payment_intents_update {
    my $self             = shift;
    my $id               = shift;
    my %param            = (@_);
    return $self->_compose('payment_intents/'.$id, %param);
}

=head3 payment_intents_confirm (I<%params>)

    my $success = $stripe->payment_intents_confirm( $payment_intents_id, 
        payment_method => 'pm_card_visa' );
    
Confirm a payment intent. It can be used just the id and no parameters if simply
confirming, or you may want to attach a payment_method for example.


=cut

sub payment_intents_confirm {
    my $self             = shift;
    my $id               = shift;
    my %param            = (@_);
    return $self->_compose('payment_intents/'.$id.'/confirm', @_ ? %param : 'post');
}

=head3 payment_intents_capture (I<%params>)

    my $success = $stripe->payment_intents_capture( $payment_intents_id, 
        amount_to_capture => 10 );

Capture an amount from a payment intent. Defaults to capture the full amount,
but you can capture a smaller amount like in the example. Payment intents are
cancelled if not captured within 7 days.

=cut

sub payment_intents_capture {
    my $self             = shift;
    my $id               = shift;
    my %param            = (@_);
    return $self->_compose('payment_intents/'.$id.'/capture', @_ ? %param : 'post');
}

=head3 payment_intents_cancel (I<%params>)

    my $success = $stripe->payment_intents_cancel( $payment_intents_id );

Simply cancel the payment intent, params are optional, you can give it a reason
for the cancellation if wanted.

=cut

sub payment_intents_cancel {
    my $self             = shift;
    my $id               = shift;
    my %param            = (@_);
    return $self->_compose('payment_intents/'.$id.'/cancel', @_ ? %param : 'post');
}

=head3 payment_intents_list (I<%params>)

    my $intent_list = $stripe->payment_intents_list( 'customer' => '<some_customer_id>' );

Grab a list of the payment intents, by some field. Will return a dictionary with a C<data> 
element, which will be an arrayref you can loop over.

=cut

sub payment_intents_list {
    my $self        = shift;
    my %params      = (@_);
    my $qs          = join '&', map {
        $_ . '=' . ($params{$_}||'')
    } sort keys %params;

    return $self->_compose('payment_intents' . ($qs ? "?$qs" : ''));
}


=head2 Setup Intents

Setup Intents are useful if you want to capture off-session payments.
For example, you may want to integrate stripe.js in the browser, get
Stripe to capture a card for future payments. An example flow, may be 
to create a setup intent at the back end, and pass the C<client_secret>
it returns to the front end, to include in the stripe.js form, when
getting Stripe to capture the card for future payments. This will help
with the authentication later hopefully making payments more likely to 
go through without issue.

=head3 setup_intents_create (I<%params>)

    my $setup_intent = $stripe->setup_intents_create(
        customer        => '<some_customer_id',
        description     => 'A setup intent',
    );

Create a setup intent, which can be used for setting up payment
credentials for later use.


=cut

sub setup_intents_create {
    my $self             = shift;
    my %param            = (@_);
    return $self->_compose('setup_intents', %param);
}

=head3 setup_intents_retrieve (I<$id>)

    my $setup_intents_data = $stripe->setup_intents_retrieve('seti_xxxx')
        and $stripe->success;

Takes the setup intent <id> value and yields data about the intent, available
on L<< $stripe->success | /success >>.

=cut

sub setup_intents_retrieve {
    my $self        = shift;
    my $id          = shift;
    return $self->_compose('setup_intents/'.$id);
}

=head3 setup_intents_update (I<$id>)

    my $updated_intent = $stripe->setup_intents_update( $setup_intent_id, 
        'description' => 'An updated setup intent' );

Update a setup intent. Returns the setup_intent object.

=cut

sub setup_intents_update {
    my $self             = shift;
    my $id               = shift;
    my %param            = (@_);
    return $self->_compose('setup_intents/'.$id, %param);
}

=head3 setup_intents_confirm (I<$id>)

    my $confirmed_intent = $stripe->setup_intents_confirm( $setup_intent_id );

Confirm a setup intent, for example with a payment method, but parameters not 
required.

=cut

sub setup_intents_confirm {
    my $self             = shift;
    my $id               = shift;
    my %param            = (@_);
    return $self->_compose('setup_intents/'.$id.'/confirm', @_ ? %param : 'post');
}

=head3 setup_intents_cancel (I<$id>)

   my $setup_intent = $stripe->setup_intents_cancel( $setup_intent_id );

Cancel a setup intent. will return the intent, or an error if already cancelled.
This doesn't need any params, but you can specify a cancellation_reason if wanted.

=cut

sub setup_intents_cancel {
    my $self             = shift;
    my $id               = shift;
    my %param            = (@_);
    return $self->_compose('setup_intents/'.$id.'/cancel', @_ ? %param : 'post');
}

=head3 setup_intents_list (I<$id>)

    my $intents_list = $stripe->setup_intents_list( 'customer' => '<some_customer_id>' );

Grab a list of setup intents, by some parameter, or no parameters to get them all. You can 
include a C<limit> parameter if needed.

=cut

sub setup_intents_list {
    my $self        = shift;
    my %params      = (@_);
    my $qs          = join '&', map {
        $_ . '=' . ($params{$_}||'')
    } sort keys %params;

    return $self->_compose('setup_intents' . ($qs ? "?$qs" : ''));
}




=head2 Customers

Some operations require you create a customer. Also, by creating a customer,
you don't have to ask for credit card information on every charge.

=head3 customers_create (I<%params>)

Creates a new customer according to the credit card information or token given.
Use this method to create a customer-ID for the given C<card>
(token when used in conjunction with Stripe.js).
The customer-ID can be passed to C<charges_create>'s C<customer> parameter
instead of C<source> so that you don't have to ask for credit card info again.

    my $customer_id = $stripe->customers_create(
        source      => 'tok_Wzm6ewTBrkVvC3',
        email       => 'customer@example.com',
        description => 'userid-123456'
    ) or die $stripe->error;

    ### charges the customer $5
    $stripe->charges_create(
        customer    => $customer_id,
        amount      => 500,
        description => 'userid-123456 paid $5'
    );

Returns the customer's ID if successful. As usual, you may check the
full JSON object returned on L<< $stripe->success | /success >>.

=cut

sub customers_create {
    my $self = shift;
    return $self->_compose('customers', @_);
}

=head3 customers_retrieve (I<$id>)

Gets the customer's object. Returns the id (which you already have) so
make sure to fetch the actual object using L<< $stripe->success | /success >>.

    my $customer = $stripe->customers_retrieve('cus_gpj0mzwbQKBI7c')
        and $stripe->success;
    die $stripe->error unless $customer;

=cut

sub customers_retrieve {
    my $self = shift;
    my $id   = shift;
    return $self->_compose('customers/'.$id);
}

=head3 customers_update (I<$id>, [I<%params>])

Updates customer's information.

    $stripe->customers_update('cus_gpj0mzwbQKBI7c',
        email => 'newemail@example.com',
    );

B<Note:> If you update the C<source> of a customer, Stripe will create
a source object with the new value, make it the default source, and
I<delete the old customer default> if it exists. If you just want to
add extra sources for that customer, refer to Stripe's
L<< card creation API | https://stripe.com/docs/api#create_card >>.

=cut

sub customers_update {
    my $self = shift;
    return $self->_compose('customers/'.(shift), @_);
}

=head3 customers_delete (I<$id>)

Deletes the customer.

 $stripe->customers_delete('cus_gpj0mzwbQKBI7c')
    or die $stripe->error;

=cut

sub customers_delete {
    my $self = shift;
    return $self->_compose('customers/'.(shift), 'delete');
}

=head3 customers_list (I<%params>)

List all customers.

 $stripe->customers_list(limit => 20);

=cut

sub customers_list {
    my $self        = shift;
    my %params      = (@_);
    my $qs          = join '&', map {
        $_ . '=' . ($params{$_}||'')
    } sort keys %params;

    return $self->_compose('customers' . ($qs ? "?$qs" : ''));
}


=head3 customers_subscribe (I<$id>, I<%params>)

Subscribes a customer to a specified plan:

    $stripe->customers_subscribe('cus_YrUZejr9oojQjs',
        'items[0][plan]' => $some_plan_id,
        'prorate'        => 'false'
    );

Assuming C<$some_plan_id> is the id of a plan already created in your
Stripe account.

B<Note:> pass C<'items[0][quantity]'> with a value of 2 or more to subscribe
the same user to 2 or more of the same plan. It defaults to 1.

B<Note:> This method will I<< replace all your user's subscriptions >> with
the new data provided. To subscribe the user to more than one plan, write:

    $stripe->api('post', 'subscriptions',
        'customer'       => $customer_id,
        'items[0][plan]' => $plan_id_to_add,
    );

Note that this will keep all previous billing cycles (and associated fees)
for any other subscription already present and add a new billing cycle (and fee)
for this new one. If you want to subscribe the customer to more than one plan
I<< with a single billing cycle >>, pass each plan as a separate item:

    $stripe->customers_subscribe('cus_YrUZejr9oojQjs',
        'items[0][plan]' => $some_plan_id,
        'items[1][plan]' => $other_plan_id,
    ) or die "error subscribing customer: " . $stripe->error->{message};

=cut

sub customers_subscribe {
    my $self        = shift;
    my $id          = shift;
    return $self->_compose("customers/$id/subscriptions", @_);
}


=head3 customers_unsubscribe (I<$id>)

Immediately unsubscribe the customer from all currently subscribed plans.
Useful for terminating accounts (or paid subscriptions).

NOTE: As per Stripe's documentation, any pending invoice items that you’ve
created will still be charged for at the end of the period, unless manually
deleted. If you’ve set the subscription to cancel at the end of the period,
any pending prorations will also be left in place and collected at the end
of the period. But if the subscription is set to cancel immediately, pending
prorations will be removed.

 $stripe->customers_unsubscribe('cus_YrUZejr9oojQjs')
    or die "error unsubscribing customer: " . $stripe->error->{message};

=cut

sub customers_unsubscribe {
    my $self        = shift;
    my $id          = shift;
    return $self->_compose("customers/$id/subscriptions", 'delete');
}


sub _init {
    my $self = shift;

    $self->{-url}     ||= URL;
    $self->{-api_key} and
    $self->{-auth}      = 'Basic ' . encode_base64($self->{-api_key}) . ':';
    if (!$self->{-ua}) {
        $self->{-ua} = LWP::UserAgent->new(
            (ref $self->{-ua_args} eq 'HASH' ? %{$self->{-ua_args}} : ())
        );
    }
    return;
}

sub _compose {
    my $self = shift;
    my $resource = shift;

    return undef unless $self->{-auth};

    # reset
    undef $self->{-success};
    undef $self->{-error};

    my $res     = undef;
    my $url     = $self->{-url} . $resource;

    my @headers = $self->_fetch_headers;

    if ($_[0] and $_[0] eq 'delete') {
        $res = $self->{-ua}->request(
            DELETE $url, @headers
        );
    } elsif (scalar @_ > 1 || (@_ == 1 && ref $_[0] eq 'ARRAY')) {
        $res = $self->{-ua}->request(
            POST $url, @headers, Content => [ @_ == 1 ? @{$_[0]} : @_ ]
        );
    # cases where we need a post but no data
    } elsif( $_[0] and $_[0] eq 'post' ) {
        $res = $self->{-ua}->request(
            POST $url, @headers
        );
    } else {
        $res = $self->{-ua}->request(
            GET $url, @headers
        );
    }

    if ($res->is_success) {
        $self->{-success} = decode_json($res->content);
        return $self->{-success}->{id} || 1;
    }

    $self->{-error} = decode_json($res->content);
    return 0;
}

sub _fetch_headers {
    my $self = shift;
    my %headers = ( Authorization => $self->{-auth} );

    if ($self->{-version}) {
        $headers{'Stripe-Version'} = $self->{-version};
    }
    if ($self->{-stripe_account}) {
        # for managed 'oauth' accounts.
        # https://stripe.com/docs/connect/authentication
        $headers{'Stripe-Account'} = $self->{-stripe_account};
    }
    return %headers;
}


=head1 REPOSITORY

L<https://github.com/aquaron/Business-Stripe>

=head1 SEE ALSO

Stripe.js Documentation L<https://stripe.com/docs/stripe.js>.

Stripe Full API Reference L<https://stripe.com/docs/api>.

Full featured implementation by Luke Closs L<Net::Stripe>.

=head1 SINGLE FILE INSTALLATION

This module is implemented as a single-file package.
If you don't want to use the CPAN distribution, you can download C<Stripe.pm>
from the root directory and renamed it to C<BusinessStripe.pm>:

 mv Stripe.pm BusinessStripe.pm

Edit C<BusinessStripe.pm> and remove the C<::> between the package name on
the first line to:

 package BusinessStripe;

Include the file in your program:

 use BusinessStripe;
 my $stripe = BusinessStripe->new(
     -api_key => 'c6EiNIusHip8x5hkdIjtur7KNUA3TTpE',
     -env_proxy => 1,
 );
 $stripe->charges_list;

=head1 AUTHOR

Paul Pham (@phamnp)

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012-2019 Aquaron. All Rights Reserved.

This program and library is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
1;
