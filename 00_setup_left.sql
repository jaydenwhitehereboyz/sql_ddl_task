CREATE EXTENSION IF NOT EXISTS dblink;

CREATE SCHEMA rep;

CREATE TABLE rep.report (
    id int4 NOT NULL,
    period varchar(12) NOT NULL,
    amount numeric(10,2),
    rate numeric(10,2),
    note text
);
COMMENT ON COLUMN rep.report.id IS 'report identifier';
COMMENT ON COLUMN rep.report.period IS 'report time period';
COMMENT ON COLUMN rep.report.note IS 'Note';

CREATE TABLE rep.client (
    client_id int2,
    payment_period varchar(32) NOT NULL,
    status text
);
COMMENT ON COLUMN rep.client.status IS 'Статус клиента';

CREATE TABLE rep.archive (
    recent_id int4,
    history varchar(32) NOT NULL,
    reason varchar(16)
);
