--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: authorizations; Type: TABLE; Schema: public; Owner: vanilla; Tablespace: 
--

CREATE TABLE authorizations (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id integer NOT NULL,
    client_id integer NOT NULL,
    code_expires_at timestamp without time zone NOT NULL,
    redirect_url text NOT NULL,
    code text NOT NULL,
    scopes text
);


ALTER TABLE public.authorizations OWNER TO vanilla;

--
-- Name: authorizations_id_seq; Type: SEQUENCE; Schema: public; Owner: vanilla
--

CREATE SEQUENCE authorizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.authorizations_id_seq OWNER TO vanilla;

--
-- Name: authorizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vanilla
--

ALTER SEQUENCE authorizations_id_seq OWNED BY authorizations.id;


--
-- Name: clients; Type: TABLE; Schema: public; Owner: vanilla; Tablespace: 
--

CREATE TABLE clients (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    store_id integer NOT NULL,
    title text NOT NULL,
    secret text NOT NULL,
    api_key text NOT NULL,
    oauth_redirect_uri text,
    skips_authorization_dialog boolean DEFAULT false NOT NULL
);


ALTER TABLE public.clients OWNER TO vanilla;

--
-- Name: clients_id_seq; Type: SEQUENCE; Schema: public; Owner: vanilla
--

CREATE SEQUENCE clients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.clients_id_seq OWNER TO vanilla;

--
-- Name: clients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vanilla
--

ALTER SEQUENCE clients_id_seq OWNED BY clients.id;


--
-- Name: nonces; Type: TABLE; Schema: public; Owner: vanilla; Tablespace: 
--

CREATE TABLE nonces (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    store_id integer NOT NULL,
    key text NOT NULL,
    value text NOT NULL,
    expires_at timestamp without time zone NOT NULL,
    user_id integer NOT NULL,
    url text,
    endpoint text,
    context text,
    delivery_status_key text
);


ALTER TABLE public.nonces OWNER TO vanilla;

--
-- Name: nonces_id_seq; Type: SEQUENCE; Schema: public; Owner: vanilla
--

CREATE SEQUENCE nonces_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.nonces_id_seq OWNER TO vanilla;

--
-- Name: nonces_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vanilla
--

ALTER SEQUENCE nonces_id_seq OWNED BY nonces.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: vanilla; Tablespace: 
--

CREATE TABLE schema_migrations (
    version character varying(255) NOT NULL
);


ALTER TABLE public.schema_migrations OWNER TO vanilla;

--
-- Name: stores; Type: TABLE; Schema: public; Owner: vanilla; Tablespace: 
--

CREATE TABLE stores (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    name text NOT NULL,
    default_url text NOT NULL,
    template_url text NOT NULL,
    scopes text,
    secret text NOT NULL,
    user_name_pattern text,
    minimum_user_name_length integer,
    maximum_user_name_length integer,
    default_sender_email_address text,
    service_settings text,
    login_methods text
);


ALTER TABLE public.stores OWNER TO vanilla;

--
-- Name: stores_id_seq; Type: SEQUENCE; Schema: public; Owner: vanilla
--

CREATE SEQUENCE stores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.stores_id_seq OWNER TO vanilla;

--
-- Name: stores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vanilla
--

ALTER SEQUENCE stores_id_seq OWNED BY stores.id;


--
-- Name: tokens; Type: TABLE; Schema: public; Owner: vanilla; Tablespace: 
--

CREATE TABLE tokens (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id integer NOT NULL,
    client_id integer NOT NULL,
    authorization_code text NOT NULL,
    access_token text NOT NULL,
    refresh_token text NOT NULL,
    scopes text,
    expires_at timestamp without time zone
);


ALTER TABLE public.tokens OWNER TO vanilla;

--
-- Name: tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: vanilla
--

CREATE SEQUENCE tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tokens_id_seq OWNER TO vanilla;

--
-- Name: tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vanilla
--

ALTER SEQUENCE tokens_id_seq OWNED BY tokens.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: vanilla; Tablespace: 
--

CREATE TABLE users (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    store_id integer NOT NULL,
    name text NOT NULL,
    password_hash text NOT NULL,
    mobile_number text,
    mobile_verified boolean DEFAULT false NOT NULL,
    email_address text,
    email_verified boolean DEFAULT false NOT NULL,
    birth_date date,
    gender text,
    deleted boolean DEFAULT false NOT NULL,
    deleted_at timestamp without time zone,
    activated boolean DEFAULT false NOT NULL,
    activated_at timestamp without time zone,
    logged_in boolean DEFAULT false NOT NULL
);


ALTER TABLE public.users OWNER TO vanilla;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: vanilla
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO vanilla;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vanilla
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vanilla
--

ALTER TABLE ONLY authorizations ALTER COLUMN id SET DEFAULT nextval('authorizations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vanilla
--

ALTER TABLE ONLY clients ALTER COLUMN id SET DEFAULT nextval('clients_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vanilla
--

ALTER TABLE ONLY nonces ALTER COLUMN id SET DEFAULT nextval('nonces_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vanilla
--

ALTER TABLE ONLY stores ALTER COLUMN id SET DEFAULT nextval('stores_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vanilla
--

ALTER TABLE ONLY tokens ALTER COLUMN id SET DEFAULT nextval('tokens_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vanilla
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: authorizations_pkey; Type: CONSTRAINT; Schema: public; Owner: vanilla; Tablespace: 
--

ALTER TABLE ONLY authorizations
    ADD CONSTRAINT authorizations_pkey PRIMARY KEY (id);


--
-- Name: clients_pkey; Type: CONSTRAINT; Schema: public; Owner: vanilla; Tablespace: 
--

ALTER TABLE ONLY clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- Name: nonces_pkey; Type: CONSTRAINT; Schema: public; Owner: vanilla; Tablespace: 
--

ALTER TABLE ONLY nonces
    ADD CONSTRAINT nonces_pkey PRIMARY KEY (id);


--
-- Name: stores_pkey; Type: CONSTRAINT; Schema: public; Owner: vanilla; Tablespace: 
--

ALTER TABLE ONLY stores
    ADD CONSTRAINT stores_pkey PRIMARY KEY (id);


--
-- Name: tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: vanilla; Tablespace: 
--

ALTER TABLE ONLY tokens
    ADD CONSTRAINT tokens_pkey PRIMARY KEY (id);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: vanilla; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_nonces_on_store_id_and_key_and_value; Type: INDEX; Schema: public; Owner: vanilla; Tablespace: 
--

CREATE INDEX index_nonces_on_store_id_and_key_and_value ON nonces USING btree (store_id, key, value);


--
-- Name: index_users_on_deleted; Type: INDEX; Schema: public; Owner: vanilla; Tablespace: 
--

CREATE INDEX index_users_on_deleted ON users USING btree (deleted);


--
-- Name: index_users_on_email_address; Type: INDEX; Schema: public; Owner: vanilla; Tablespace: 
--

CREATE INDEX index_users_on_email_address ON users USING btree (email_address);


--
-- Name: index_users_on_email_verified; Type: INDEX; Schema: public; Owner: vanilla; Tablespace: 
--

CREATE INDEX index_users_on_email_verified ON users USING btree (email_verified);


--
-- Name: index_users_on_mobile_number; Type: INDEX; Schema: public; Owner: vanilla; Tablespace: 
--

CREATE INDEX index_users_on_mobile_number ON users USING btree (mobile_number);


--
-- Name: index_users_on_mobile_verified; Type: INDEX; Schema: public; Owner: vanilla; Tablespace: 
--

CREATE INDEX index_users_on_mobile_verified ON users USING btree (mobile_verified);


--
-- Name: index_users_on_name; Type: INDEX; Schema: public; Owner: vanilla; Tablespace: 
--

CREATE INDEX index_users_on_name ON users USING btree (name);


--
-- Name: index_users_on_store_id; Type: INDEX; Schema: public; Owner: vanilla; Tablespace: 
--

CREATE INDEX index_users_on_store_id ON users USING btree (store_id);


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: vanilla; Tablespace: 
--

CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations USING btree (version);


--
-- Name: authorizations_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vanilla
--

ALTER TABLE ONLY authorizations
    ADD CONSTRAINT authorizations_client_id_fkey FOREIGN KEY (client_id) REFERENCES clients(id);


--
-- Name: authorizations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vanilla
--

ALTER TABLE ONLY authorizations
    ADD CONSTRAINT authorizations_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: clients_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vanilla
--

ALTER TABLE ONLY clients
    ADD CONSTRAINT clients_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id);


--
-- Name: nonces_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vanilla
--

ALTER TABLE ONLY nonces
    ADD CONSTRAINT nonces_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id);


--
-- Name: nonces_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vanilla
--

ALTER TABLE ONLY nonces
    ADD CONSTRAINT nonces_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: tokens_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vanilla
--

ALTER TABLE ONLY tokens
    ADD CONSTRAINT tokens_client_id_fkey FOREIGN KEY (client_id) REFERENCES clients(id);


--
-- Name: tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vanilla
--

ALTER TABLE ONLY tokens
    ADD CONSTRAINT tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: users_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vanilla
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id);


--
-- PostgreSQL database dump complete
--

