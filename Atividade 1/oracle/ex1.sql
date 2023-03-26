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
        JOIN Felipe.Book bo ON bl.book_id = bo.book_id
        JOIN Felipe.Library_Branch lb ON bl.branch_id = lb.branch_id
        WHERE (bl.due_date - bl.date_out) > 30;

-- eu simplesmente esqueci de fazer o update no pgsql então
-- estou fazendo aqui, antes tarde do que nunca
CREATE OR REPLACE TRIGGER Felipe.Update_Month_Borrowers
	AFTER INSERT OR UPDATE OR DELETE ON Felipe.Book_Loans
	DECLARE
        PRAGMA AUTONOMOUS_TRANSACTION;
	BEGIN 
		DBMS_MVIEW.REFRESH('Felipe.Month_Borrowers');
	END;

	
-- eu juro que tentei fazer direto na criação da view
-- a parte de atualizar com REFRESH ON COMMIT
-- mas deu algum problema por causa dos joins
-- então eu fiz o trigger

-- CREATE MATERIALIZED VIEW LOG ON Felipe.Book_Loans
--     WITH PRIMARY KEY, ROWID, SEQUENCE (date_out, due_date)
-- INCLUDING NEW VALUES;

-- CREATE MATERIALIZED VIEW LOG ON Felipe.Book
--     WITH PRIMARY KEY, ROWID, SEQUENCE (title, publisher_name)
-- INCLUDING NEW VALUES;

-- CREATE MATERIALIZED VIEW LOG ON Felipe.Borrower
--     WITH PRIMARY KEY, ROWID, SEQUENCE (name, address, phone)
-- INCLUDING NEW VALUES;

-- CREATE MATERIALIZED VIEW LOG ON Felipe.Library_Branch
--     WITH PRIMARY KEY, ROWID, SEQUENCE (branch_name, address)
-- INCLUDING NEW VALUES;