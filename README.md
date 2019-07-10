Business::Stripe
================

This module provides common Perl 5 bindings to the Stripe payment system
with minimal dependencies and overhead.

Any API calls that do not have bindings can be easily accessed through the
generic `api` method.

Basic Usage
-----------

```perl
    my $stripe = Business::Stripe->new(
        -api_key => 'your-api-key-here',
    );

    ## get the payment token from Stripe.js, then:
    my $success = $stripe->charges_create(
        amount         => 400,  # in cents
        source         => $token_from_stripe_js,
        description    => 'Ice cream'
    );

    if ($success) {
        return $stripe->success();  # <-- the returned JSON structure
    }
    else {
        die $stripe->error->{message};
    }

    my $customer = $stripe->api('post', 'customers',
        email       => 'myuser@example.com',
        name        => 'Jane S. Customer',
        description => 'Displayed alongside the customer on your dashboard',
        source      => $token_id,
    ) and $stripe->success;
    die $stripe->error unless $customer;
```

Please refer to [Business::Stripe's complete documentation](https://metacpan.org/pod/Business::Stripe)
for more examples and thorough documentation. After installation, the same
documentation may be accessed on your terminal by typing:

    perldoc Business::Stripe

on your terminal.


Installation
------------

To install this module via cpanm:

    > cpanm Business::Stripe

Or, at the cpan shell:

    cpan> install Business::Stripe

If you wish to install it manually, download and unpack the tarball and
run the following commands:

	perl Makefile.PL
	make
	make test
	make install

Of course, instead of downloading the tarball you may simply clone the
git repository:

    $ git clone git://github.com/aquaron/Business-Stripe.git

Finally, you can also just download Stripe.pm and include it as part of your
distribution (though in this case you should probably rename it to something
like `BusinessStripe.pm`).


LICENSE AND COPYRIGHT
---------------------

Copyright (C) 2016-2019 Aquaron. All Rights Reserved.

This program and library is free software; 
you can redistribute it and/or modify it under the same terms as Perl 5 itself.

See http://dev.perl.org/licenses/ for more information.
