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
-- Name: db_info; Type: TABLE; Schema: public; Owner: pprime; Tablespace: 
--

CREATE TABLE db_info (
    dbversion integer NOT NULL
);


ALTER TABLE public.db_info OWNER TO pprime;

--
-- Name: lock_table; Type: TABLE; Schema: public; Owner: pprime; Tablespace: 
--

CREATE TABLE lock_table (
    device character varying(32) NOT NULL,
    ltolabel character varying(8)
);


ALTER TABLE public.lock_table OWNER TO pprime;

--
-- Name: lto_info; Type: TABLE; Schema: public; Owner: pprime; Tablespace: 
--

CREATE TABLE lto_info (
    label character varying(8) NOT NULL,
    free integer,
    booked integer,
    inuse character varying(1),
    poolname character varying(16),
    ltotype character varying(4) DEFAULT 'n/a'::character varying
);


ALTER TABLE public.lto_info OWNER TO pprime;

--
-- Name: requests; Type: TABLE; Schema: public; Owner: pprime; Tablespace: 
--

CREATE TABLE requests (
    id integer NOT NULL,
    uuid character varying(36) NOT NULL,
    status character varying(12),
    substatus integer,
    operation character varying(1) NOT NULL,
    manager character varying(1) NOT NULL,
    sourcefile character varying(255) NOT NULL,
    checksum character varying(10),
    sourcesize integer,
    sourcebytes bigint,
    datatype character varying(1),
    destfile character varying(255),
    callinghost character varying(64),
    poolname character varying(16),
    callingtime timestamp with time zone NOT NULL,
    starttime timestamp with time zone,
    endtime timestamp with time zone,
    errorcode integer,
    errordescription text,
    ltotape character varying(8) DEFAULT 'n/a'::character varying,
    ltolibrary character varying(32),
    checksumfile character varying(255) DEFAULT 'none'::character varying,
    device character varying(32) DEFAULT 'n/a'::character varying
);


ALTER TABLE public.requests OWNER TO pprime;

--
-- Name: requests_id_seq; Type: SEQUENCE; Schema: public; Owner: pprime
--

CREATE SEQUENCE requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.requests_id_seq OWNER TO pprime;

--
-- Name: requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pprime
--

ALTER SEQUENCE requests_id_seq OWNED BY requests.id;


--
-- Name: requests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: pprime
--

SELECT pg_catalog.setval('requests_id_seq', 671, true);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: pprime
--

ALTER TABLE ONLY requests ALTER COLUMN id SET DEFAULT nextval('requests_id_seq'::regclass);


--
-- Data for Name: db_info; Type: TABLE DATA; Schema: public; Owner: pprime
--

COPY db_info (dbversion) FROM stdin;
1
\.

--
-- Name: db_info_pkey; Type: CONSTRAINT; Schema: public; Owner: pprime; Tablespace: 
--

ALTER TABLE ONLY db_info
    ADD CONSTRAINT db_info_pkey PRIMARY KEY (dbversion);


--
-- Name: lock_table_pkey; Type: CONSTRAINT; Schema: public; Owner: pprime; Tablespace: 
--

ALTER TABLE ONLY lock_table
    ADD CONSTRAINT lock_table_pkey PRIMARY KEY (device);


--
-- Name: lto_info_pkey; Type: CONSTRAINT; Schema: public; Owner: pprime; Tablespace: 
--

ALTER TABLE ONLY lto_info
    ADD CONSTRAINT lto_info_pkey PRIMARY KEY (label);


--
-- Name: requests_pkey; Type: CONSTRAINT; Schema: public; Owner: pprime; Tablespace: 
--

ALTER TABLE ONLY requests
    ADD CONSTRAINT requests_pkey PRIMARY KEY (uuid);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

