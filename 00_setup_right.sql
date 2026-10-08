CREATE SCHEMA rep;

CREATE TABLE rep.report (
    id int2,
    period varchar(20) NOT NULL,
    rate numeric(12,2),
    note text,
    extra text
);
COMMENT ON COLUMN rep.report.id IS 'ID';
COMMENT ON COLUMN rep.report.period IS 'Период';
COMMENT ON COLUMN rep.report.note IS 'Комментарий';

CREATE TABLE rep.client (
    client_id int2,
    payment_period varchar(32) NOT NULL,
    status text
);
COMMENT ON COLUMN rep.client.status IS 'Статус клиента';

CREATE TABLE rep.log (
    message_code int8,
    action_required varchar(24),
    status_message varchar(32) NOT NULL
);
