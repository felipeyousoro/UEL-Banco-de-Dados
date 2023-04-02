CREATE GLOBAL TEMPORARY TABLE Book_Copies_Temp
    ON COMMIT PRESERVE ROWS
    AS SELECT * FROM Felipe.Book_Copies;

DROP TABLE Felipe.Book_Copies;

CREATE TABLE Felipe.Book_Status (
    book_status_id NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
    acquisition_date DATE DEFAULT SYSDATE NOT NULL,
    current_condition VARCHAR2(255) DEFAULT 'good' NOT NULL,
    book_id INT NOT NULL,
    branch_id INT NOT NULL,

    CONSTRAINT PK_Book_Status PRIMARY KEY (book_status_id),
    CONSTRAINT FK_Book_Status_Branch FOREIGN KEY (branch_id) REFERENCES Felipe.Library_Branch(branch_id),
    CONSTRAINT FK_Book_Status_Book FOREIGN KEY (book_id) REFERENCES Felipe.Book(book_id),
    CONSTRAINT CHK_Book_Status_Current_Condition CHECK (current_condition IN ('fine', 'good', 'fair', 'poor'))

);

CREATE OR REPLACE FUNCTION Felipe.Check_Copy_Inconsistencies(p_book_id INT, p_branch_id INT)
    RETURN INT
    IS
        v_copies_book_copies INT;
        v_copies_book_status INT;
    BEGIN
        SELECT COUNT(*) INTO v_copies_book_status FROM Felipe.Book_Status bs
        WHERE bs.book_id = p_book_id AND bs.branch_id = p_branch_id;

        SELECT bc.no_of_copies INTO v_copies_book_copies FROM Book_Copies_Temp bc
        WHERE bc.book_id = p_book_id AND bc.branch_id = p_branch_id;

        RETURN v_copies_book_copies - v_copies_book_status;
    END;

CREATE OR REPLACE TYPE Felipe.T_Copy_Inconsistencies_Row AS OBJECT(
    book_id INT,
    branch_id INT,
    copies_diff INT
);

CREATE OR REPLACE TYPE Felipe.T_Copy_Inconsistencies_Tab IS TABLE OF Felipe.T_Copy_Inconsistencies_Row;

CREATE OR REPLACE PACKAGE Felipe.Copy_Inconsistencies_Pack
    IS
        FUNCTION Get_Copies_Inconsistencies RETURN Felipe.T_Copy_Inconsistencies_Tab PIPELINED;
    END;

CREATE OR REPLACE PACKAGE BODY Felipe.Copy_Inconsistencies_Pack
    AS
        FUNCTION Get_Copies_Inconsistencies RETURN Felipe.T_Copy_Inconsistencies_Tab PIPELINED IS
            BEGIN
                FOR rec IN (SELECT bc.book_id, bc.branch_id, Felipe.Check_Copy_Inconsistencies(bc.book_id, bc.branch_id) AS copy_inconsistencies
                            FROM Book_Copies_Temp bc
                            WHERE Felipe.Check_Copy_Inconsistencies(bc.book_id, bc.branch_id) <> 0)
                LOOP
                    PIPE ROW (Felipe.T_Copy_Inconsistencies_Row(rec.book_id, rec.branch_id, rec.copy_inconsistencies));
                END LOOP;

                RETURN;
    END;
END;

CREATE OR REPLACE PROCEDURE Felipe.Fix_Copy_Inconsistencies(p_copy T_Copy_Inconsistencies_Row)
    IS
        book INT;
    BEGIN
        FOR book IN 1..p_copy.copies_diff LOOP
            INSERT INTO Felipe.Book_Status (book_id, branch_id) VALUES (p_copy.book_id, p_copy.branch_id);
        END LOOP;
    END;

CREATE OR REPLACE PROCEDURE Felipe.Remove_Copies_Inconsistencies IS
    BEGIN
        FOR v_copy IN (SELECT * FROM TABLE(Felipe.Copy_Inconsistencies_Pack.Get_Copies_Inconsistencies())) LOOP
            Felipe.Fix_Copy_Inconsistencies(T_Copy_Inconsistencies_Row(v_copy.book_id, v_copy.branch_id, v_copy.copies_diff));
        END LOOP;
    END;

BEGIN
    Felipe.Remove_Copies_Inconsistencies;
END;


-- Como as funcoes e procedimentos foram feitas com o proposito de fazer
-- uma transicao de sistema, entao acho que faz sentido dropar elas depois
DROP PROCEDURE Felipe.Remove_Copies_Inconsistencies;
DROP PROCEDURE Felipe.Fix_Copy_Inconsistencies;
DROP FUNCTION Felipe.Check_Copy_Inconsistencies;
DROP PACKAGE Felipe.Copy_Inconsistencies_Pack;
DROP TYPE Felipe.T_Copy_Inconsistencies_Tab;
DROP TYPE Felipe.T_Copy_Inconsistencies_Row;

ALTER TABLE Felipe.Book_Loans
    ADD (book_status_id NUMBER);
ALTER TABLE Felipe.Book_Loans
    DROP CONSTRAINT PK_Book_Loans;
ALTER TABLE Felipe.Book_Loans
    DROP CONSTRAINT FK_Book_Loans_Book;
ALTER TABLE Felipe.Book_Loans
    DROP CONSTRAINT FK_Book_Loans_Branch;

CREATE OR REPLACE FUNCTION Felipe.Get_Available_Copy_Given_Day(p_book_id INT, p_branch_id INT, p_day DATE)
    RETURN INT
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        v_book_status_id INT;
    BEGIN
        SELECT bs.book_status_id INTO v_book_status_id
        FROM Felipe.Book_Status bs
        WHERE bs.book_id = p_book_id AND
            bs.branch_id = p_branch_id AND
            bs.book_status_id NOT IN
                (SELECT bl.book_status_id
                FROM Felipe.Book_Loans bl
                WHERE bl.book_id = p_book_id AND
                    bl.branch_id = p_branch_id AND
                    bl.date_out <= p_day AND
                    bl.due_date >= p_day AND
                    book_status_id IS NOT NULL)
        AND ROWNUM = 1;

        RETURN v_book_status_id;
    END;

CREATE OR REPLACE TYPE Felipe.Book_Loans_T AS OBJECT(
    book_id INT,
    branch_id INT,
    card_no INT,
    date_out DATE,
    due_date DATE

);

CREATE OR REPLACE TYPE Felipe.Book_Loans_T_Tab IS TABLE OF Felipe.Book_Loans_T;

CREATE OR REPLACE PACKAGE Felipe.Book_Loans_Pack
    IS
        PROCEDURE Add_Copy_Book_Loan(p_loan Felipe.Book_Loans_T);
    END;

-- CREATE OR REPLACE PROCEDURE Felipe.Add_Copy_Book_Loan(p_loan Felipe.Book_Loans_T)
--     IS
--     BEGIN
--         UPDATE Felipe.Book_Loans
--             SET
--                 book_status_id = Felipe.Get_Available_Copy_Given_Day(p_loan.book_id, p_loan.branch_id, p_loan.date_out)
--             WHERE
--                 book_id = p_loan.book_id AND
--                 branch_id = p_loan.branch_id AND
--                 card_no = p_loan.card_no;
--
--     END;
CREATE OR REPLACE PACKAGE BODY Felipe.Book_Loans_Pack
    AS
        PROCEDURE Add_Copy_Book_Loan(p_loan Felipe.Book_Loans_T)
            IS
            BEGIN
                UPDATE Felipe.Book_Loans
                    SET
                        book_status_id = Felipe.Get_Available_Copy_Given_Day(p_loan.book_id, p_loan.branch_id, p_loan.date_out)
                    WHERE
                        book_id = p_loan.book_id AND
                        branch_id = p_loan.branch_id AND
                        card_no = p_loan.card_no;
            END;
    END;

CREATE OR REPLACE PROCEDURE Felipe.Update_Book_Loans
    IS
        CURSOR c_book_loans IS SELECT * FROM Felipe.Book_Loans;
        v_loan c_book_loans%ROWTYPE;
    BEGIN
        OPEN c_book_loans;
        LOOP
            FETCH c_book_loans INTO v_loan;
            EXIT WHEN c_book_loans%NOTFOUND;
            Felipe.Book_Loans_Pack.Add_Copy_Book_Loan(Felipe.Book_Loans_T(v_loan.book_id, v_loan.branch_id, v_loan.card_no, v_loan.date_out, v_loan.due_date));
        END LOOP;
        CLOSE c_book_loans;
    END;

BEGIN
    Felipe.Update_Book_Loans();
END;

DROP PROCEDURE Felipe.Update_Book_Loans;
DROP PACKAGE Felipe.Book_Loans_Pack;
DROP TYPE Felipe.Book_Loans_T_Tab;
DROP TYPE Felipe.Book_Loans_T;


ALTER TABLE Felipe.Book_Loans
    ADD CONSTRAINT PK_Book_Loans PRIMARY KEY (book_status_id, date_out);
ALTER TABLE Felipe.Book_Loans
    DROP COLUMN book_id;
ALTER TABLE Felipe.Book_Loans
    DROP COLUMN branch_id;

TRUNCATE TABLE Book_Copies_Temp;
DROP TABLE Book_Copies_Temp;

-- Fazendo a view
CREATE VIEW Felipe.Book_Copies (
    book_id,
    branch_id,
    no_of_copies ) AS
    SELECT
        bs.book_id,
        bs.branch_id,
        COUNT(*)
        FROM Felipe.Book_Status bs
        GROUP BY bs.book_id, bs.branch_id
        ORDER BY bs.book_id, bs.branch_id;

CREATE OR REPLACE PROCEDURE Felipe.Add_New_Books(p_book_id INT, p_branch_id INT, p_old_no_of_copies INT,
                                                 p_new_no_of_copies INT)
    IS
        v_copy INT;
    BEGIN
        FOR v_copy in p_old_no_of_copies + 1 .. p_new_no_of_copies
            LOOP
                INSERT INTO Felipe.Book_Status (book_id, branch_id)
                VALUES (p_book_id, p_branch_id);
            END LOOP;
    END;


CREATE OR REPLACE TRIGGER Felipe_Update_Book_Copies
    INSTEAD OF INSERT OR DELETE OR UPDATE ON Felipe.Book_Copies
    FOR EACH ROW
    DECLARE
        v_copy INT;
    BEGIN
        IF INSERTING THEN
            FOR v_copy IN 1..:NEW.no_of_copies LOOP
                INSERT INTO Felipe.Book_Status (book_id, branch_id)
                    VALUES (:NEW.book_id, :NEW.branch_id);
            END LOOP;
        ELSIF DELETING THEN
            DELETE FROM Felipe.Book_Status
                WHERE book_id = :OLD.book_id AND
                branch_id = :OLD.branch_id;
        ELSIF UPDATING THEN
            IF :OLD.no_of_copies > :NEW.no_of_copies THEN
                RETURN;
            ELSE
                UPDATE Felipe.Book_Status SET
                    book_id = :NEW.book_id,
                    branch_id = :NEW.branch_id
                    WHERE book_id = :OLD.book_id AND
                    branch_id = :OLD.branch_id;

                Felipe.Add_New_Books(:NEW.book_id, :NEW.branch_id, TO_NUMBER(:OLD.no_of_copies), TO_NUMBER(:NEW.no_of_copies));
            END IF;
        END IF;
    END;
