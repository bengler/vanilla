Vanilla
=======

[![Build Status](https://semaphoreapp.com/api/v1/projects/f8a20614eda0f345d510e925dfc4fe8cc8e83a88/28276/badge.png)](https://semaphoreapp.com/projects/1578/branches/28276)

Vanilla is a simple, reusable user database component designed to work as an OAuth provider for any application:

* Designed to work with [Checkpoint](https://github.com/bengler/checkpoint) and [Pebblestack](http://pebblestack.org/), but this is optional.
* Multi-tenant, can host many different client applications.
* [OAuth 2.0](http://tools.ietf.org/html/draft-ietf-oauth-v2-25) (draft 25) provider.
* Login session management.
* Secure salted password storage.
* I18n-ready.

Internals
---------

Vanilla uses ActiveRecord for database bindings.

Templating is currently provided entirely by client application.

Running
-------

* Use `config/database-example.yml` as a starting point to create `config/database.yml`.
* Create database: `bundle exec rake db:bootstrap`.
* To run with Pow, symlink folder into `~/.pow`.
* To run with Unicorn, start with `bundle exec unicorn config.ru`.

Templating
----------

Vanilla does not have an UI as such. Instead, it delegates all UI interactions to the client application. It does this by sending template requests to the client app.

For example, let's say the client application is on `example.com`, and that Vanilla is hosted on `vanilla.example.com`. To render the login page, the user reaches the Vanilla URL:

    http://vanilla.example.com/api/vanilla/v1/login

This then internally calls the client app to render a login page:

    http://example.com/vanilla_template?template=login&return_url=...

It is the client app's responsibility to render a nice-looking login page using whatever technology it prefers.

See `TEMPLATES.md` for overview of templates.

Todo
----

* Render i18n-independent validation errors.
* Policy config for whether mobile, email are required.
* Move verification of mobile, email to external component(s) (Hermes).
* Tight integration with Checkpoint is probably a good idea.

License
-------

See `LICENSE` file.
