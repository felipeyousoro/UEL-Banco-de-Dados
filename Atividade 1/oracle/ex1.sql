-- eu juro que tentei criar materialized view com
-- REFRESH ON COMMIT
-- eu criei os logs, passei o comando de refresh na criação da view
-- mas ela não funcionou por causa dos joins 
-- quando havia 1 join apenas funcionava, mas quando tinha 2 ou mais não

-- então eu decidi criar a tabela normalmente
-- e criar o trigger de forma parecida que tinha no exercicio de pgsql 
-- (que eu esqueci de incluir no envio semana passada, entao deixei ali embaixo) 
CREATE MATERIALIZED VIEW Felipe.month_borrowers 
    (
    card_no,
    name,
    address,
    phone,
    loan_length,
    book_title,
    branch_name ) AS
    SELECT b.card_no,
            b.name,
            b.address,
            b.phone,
            (bl.due_date - bl.date_out) AS loan_length,
            bo.title                    AS book_title,
            lb.branch_name
        FROM Felipe.Borrower b
        JOIN Felipe.Book_Loans bl ON b.card_no = bl.card_no
        JOIN Felipe.Book bo ON bl.book_id = bo.book_id -- a partir daqui dava erro se eu fizesse refresh on commit
        JOIN Felipe.Library_Branch lb ON bl.branch_id = lb.branch_id
        WHERE (bl.due_date - bl.date_out) > 30;

CREATE OR REPLACE TRIGGER Felipe.Update_Month_Borrowers
	AFTER INSERT OR UPDATE OR DELETE ON Felipe.Book_Loans
	DECLARE
        PRAGMA AUTONOMOUS_TRANSACTION;
	BEGIN 
		DBMS_MVIEW.REFRESH('Felipe.Month_Borrowers');
	END;

-- o de pgsql fiz ficou assim:
-- CREATE OR REPLACE FUNCTION Book_Loans.refresh_month_borrowers() RETURNS trigger AS $$
--     BEGIN
--         REFRESH MATERIALIZED VIEW Book_Loans.month_borrowers;
--         RETURN NULL;
--     END;
-- $$ LANGUAGE plpgsql;

-- CREATE TRIGGER refresh_month_borrowers
--     AFTER INSERT OR UPDATE OR DELETE ON Book_Loans.Book_Loans
--         FOR EACH STATEMENT
--             EXECUTE FUNCTION Book_Loans.refresh_month_borrowers();
