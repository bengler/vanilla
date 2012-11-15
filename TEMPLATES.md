Templates
=========

**Note: This list is incomplete.**

Common parameters
-----------------

The following parameters apply to most templates:

* `return_url`: Originating URL that the application can redirect back to. Typically used to produce a "Cancel" button.
* `format`: The format expected from the template. Defaults to `html` if not provided. The `Accept` header is also set to reflect the expected format.
* `error`: If set, the previous attempt failed, and this is the error name (eg., `identification_not_recognized`).
* `uid`: The UID of the current user, if any.

Common responses
----------------

Emails are returned as JSON hashes with the following keys and values:

* `subject`: Email subject.
* `from` (optional): Email sender. Defaults to realm's sender.
* `text` (optional): Text body.
* `html` (optional): HTML body.

`login`
-------

This template must render a login form.

### Received parameters

* `submit_url`: URL that the form should be submitted to.
* `return_url`: See top section.
* `error`: See top section.

### Expected behaviour

The template's form should POST its data as a JSON hash or `application/x-www-form-urlencoded` with the following keys:

* `identification`: Identifying credential. Typically user name, mobile number or email address.
* `password`: Password.
* `persistent`: If `true`, the user wants the login to be remembered for a time, otherwise the login should be limited to the current browser session.

`signup`
--------

This template must render a signup form.

### Received parameters

* `submit_url`: URL that code and password should be submitted to.
* `name`: User name (if previously entered).
* `password`: Password (if previously entered).
* `password_confirmation`: Password confirmation (if previously entered).
* `mobile_number`: Mobile number (if previously entered).
* `email_address`: Email address (if previously entered).
* `error`: See top section.

### Expected behaviour

The template's form should POST its data as a JSON hash or `application/x-www-form-urlencoded` with the following keys:

* `name`: User name.
* `password`: Password.
* `password_confirmation`: Password confirmation (may be omitted).
* `mobile_number`: Mobile number.
* `email_address`: Email address.

`validation_code_sms`
---------------------

This template must render a plaintext SMS containing a signup validation code and/or validation URL.

### Received parameters

* `code`: The validation code. 
* `url`: URL to perform validation.
* `format`: `plaintext`.

### Expected behaviour

The template must return a plaintext SMS.

`validation_code_email`
-----------------------

This template must render an email structure containing a signup validation code and/or validation URL.

### Received parameters

* `code`: The validation code. 
* `url`: URL to perform validation.
* `format`: `json`.

### Expected behaviour

The template must return a JSON hash for the email. See common responses above.

`duplicate_signup`
------------------

This template is invoked when a duplicate signup is attempted. The template should explain the problem and offer to recover the account.

### Received parameters

* `mobile_number`: The user's attempted signup mobile, if any.
* `email_address`: The user's attempted signup email, if any.
* `recovery_url`: URL to recovery page.
* `cancel_url`: URL back to signup page.

### Expected behaviour

The page should provide a button to send the user to `submit_url`, or return via `cancel_url`.

`recovery_request`
------------------

This template must render a page that accepts a verified credential (typically mobile number or email address) where the app can send a recovery code/link. This code/link can then be used to recover the account and set a new password.

### Received parameters

* `submit_url`: URL that the identification should be submitted to.

### Expected behaviour

The page must perform a `POST` against `submit_url` with the parameters (either provided in the URL or as `application/x-www-form-urlencoded` data):

* `identification`: A mobile number or email address.

The page may alternatively redirect to `return_url`.

`recovery_code_validation`
--------------------------

This template must render a form that accepts a recovery code, as well as asks the user for the password to set.

### Received parameters

* `submit_url`: URL that code and password should be submitted to.
* `return_url`: See top section.
* `identification`: The identification given in `request_recovery`.
* `error`: See top section.

### Expected behaviour

The page must perform a `POST` against `submit_url` with the parameters (either provided in the URL or as `application/x-www-form-urlencoded` data):

* `code`: The recovery code.
* `password`: The new password.
* `password_confirmation` (optional): The new password, repeated for confirmation.

The page may alternatively redirect to `return_url`.

`recovery_password_reset`
-------------------------

This template must render a form that asks the user for the password to set.

### Received parameters

* `submit_url`: URL that code and password should be submitted to.
* `return_url`: See top section.
* `identification`: The identification given in `request_recovery`.
* `error`: See top section.

### Expected behaviour

The page must perform a `POST` against `submit_url` with the parameters (either provided in the URL or as `application/x-www-form-urlencoded` data):

* `password`: The new password.
* `password_confirmation` (optional): The new password, repeated for confirmation.

The page may alternatively redirect to `return_url`.

`recovery_code_sms`
-------------------

This template must render a plaintext SMS containing the recovery code and/or recovery URL.

### Received parameters

* `code`: The recovery code. 
* `submit_url`: URL that code and password should be submitted to.
* `format`: `plaintext`.

### Expected behaviour

The template must return a plaintext SMS.

`recovery_code_email`
---------------------

This template must render an email structure containing the recovery code and/or recovery URL.

### Received parameters

* `code`: The recovery code. 
* `submit_url`: URL that code and password should be submitted to.
* `format`: `json`.

### Expected behaviour

The template must return a JSON hash for the email. See common responses above.

`authorize`
-----------

This template must render an OAuth authorization dialog that lets the user allow or deny an authorization on behalf of a client application.

### Received parameters

* `client_title`: The name of the client application requesting authorization.
* `allow_url`: URL to granting authorization. The URL must be POSTed to.
* `deny_url`: URL to denying authorization. The URL must be POSTed to.
* `scopes`: The scopes (as a hash of name to description) requested by the client.

### Expected behaviour

The template must provide a form for the user to allow or deny the authorization.
