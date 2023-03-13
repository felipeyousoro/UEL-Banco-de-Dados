BEGIN;

	CREATE TEMPORARY TABLE Book_Copies_Temp AS (
		SELECT * FROM Book_Copies
	
	);
	DROP TABLE Book_Copies;

		
	CREATE TABLE Book_Status (
		book_status_id SERIAL NOT NULL,
		acquisition_date DATE NOT NULL DEFAULT CURRENT_DATE,
		current_condition VARCHAR(255) NOT NULL DEFAULT 'good',
        book_id INT NOT NULL,
		branch_id INT NOT NULL,

		CONSTRAINT PK_Book_Status PRIMARY KEY (book_status_id),
        CONSTRAINT FK_Book_Status_Branch FOREIGN KEY (branch_id) REFERENCES Library_Branch(branch_id),
		CONSTRAINT FK_Book_Status_Book FOREIGN KEY (book_id) REFERENCES Book(book_id),
		CONSTRAINT CHK_Book_Status_Current_Condition CHECK (current_condition IN ('fine', 'good', 'fair', 'poor'))
	
	);
	
	CREATE OR REPLACE FUNCTION Check_Copy_Inconsistencies(_book_id INT, _branch_id INT) RETURNS INT AS $$
		DECLARE copies_book_copies INT;
		DECLARE copies_book_status INT;
		BEGIN
			copies_book_status := COUNT(*) FROM Book_Status AS bs
									WHERE bs.book_id = _book_id 
										AND bs.branch_id = _branch_id;
										
			copies_book_copies := bc.no_of_copies FROM Book_Copies_Temp AS bc
									WHERE bc.book_id = _book_id 
										AND bc.branch_id = _branch_id;
										
			RETURN copies_book_copies - copies_book_status;
		END;
		
	$$ LANGUAGE plpgsql;
		
	CREATE TEMPORARY TABLE Copy_Inconsistencies (
		book_id INT NOT NULL,
		branch_id INT NOT NULL,
		copies_diff INT NOT NULL
	);
	
	CREATE OR REPLACE FUNCTION Get_Copies_Inconsistencies() RETURNS SETOF Copy_Inconsistencies AS $$
		BEGIN
			RETURN QUERY SELECT bc.book_id, bc.branch_id, Check_Copy_Inconsistencies(bc.book_id, bc.branch_id) 
				FROM Book_Copies_Temp AS bc 
					WHERE Check_Copy_Inconsistencies(bc.book_id, bc.branch_id) <> 0;
		END;
		
	$$ LANGUAGE plpgsql;

  	CREATE OR REPLACE FUNCTION Fix_Copy_Inconsistencies(_copy Copy_Inconsistencies) RETURNS VOID AS $$
		DECLARE book INT;
		BEGIN
			FOR book IN 1.._copy.copies_diff LOOP
                	INSERT INTO Book_Status (book_id, branch_id) VALUES (_copy.book_id, _copy.branch_id);
			END LOOP;
		END;
		
	$$ LANGUAGE plpgsql;
	
	CREATE OR REPLACE FUNCTION Remove_Copies_Inconsistencies() RETURNS VOID AS $$
        DECLARE _copy Copy_Inconsistencies;
        BEGIN
            FOR _copy IN SELECT * FROM Get_Copies_Inconsistencies() LOOP
                PERFORM Fix_Copy_Inconsistencies(_copy);
            END LOOP;
        END;
		
	$$ LANGUAGE plpgsql;
	
	SELECT Remove_Copies_Inconsistencies();

	ALTER TABLE Book_Loans 
		ADD COLUMN book_status_id INT;
	ALTER TABLE Book_Loans
		DROP CONSTRAINT PK_Book_Loans;
	ALTER TABLE Book_Loans
		DROP CONSTRAINT FK_Book_Loans_Book;
	ALTER TABLE Book_Loans
		DROP CONSTRAINT FK_Book_Loans_Branch;
		
	CREATE OR REPLACE FUNCTION Get_Available_Copy_Given_Day(_book_id INT, _branch_id INT, _day DATE) RETURNS INT AS $$
		BEGIN
			RETURN (SELECT bs.book_status_id FROM Book_Status AS bs
                    WHERE bs.book_id = _book_id AND
                        bs.branch_id = _branch_id AND
						            bs.book_status_id NOT IN 
                            (SELECT bl.book_status_id FROM Book_Loans AS bl
                                WHERE bl.book_id = _book_id AND
                                bl.branch_id = _branch_id AND
                                bl.date_out <= _day AND
                                bl.due_date >= _day AND
                                  book_status_id IS NOT NULL)
										
                    LIMIT 1);
		
		END;
		
	$$ LANGUAGE plpgsql;
		
	CREATE OR REPLACE FUNCTION Add_Copy_Book_Loan(_loan Book_Loans) RETURNS VOID AS $$
        BEGIN
            UPDATE Book_Loans
				SET 
					book_status_id = Get_Available_Copy_Given_Day(_loan.book_id, _loan.branch_id, _loan.date_out)
				WHERE
					book_id = _loan.book_id AND
					branch_id = _loan.branch_id AND
					card_no = _loan.card_no;
					
        END;
	$$ LANGUAGE plpgsql;
	
	CREATE OR REPLACE FUNCTION Update_Book_Loans() RETURNS VOID AS $$
		DECLARE _loan Book_Loans;
		BEGIN
			FOR _loan IN SELECT * FROM Book_Loans LOOP
				PERFORM Add_Copy_Book_Loan(_loan);
			END LOOP;
		END;
		
	$$ LANGUAGE plpgsql;
	
	SELECT Update_Book_Loans();
	
 	ALTER TABLE Book_Loans
 		ADD CONSTRAINT PK_Book_Loans PRIMARY KEY (book_status_id, date_out);
 	ALTER TABLE Book_Loans
 		DROP COLUMN book_id;
 	ALTER TABLE Book_Loans
		DROP COLUMN branch_id;
		
	DROP TABLE Book_Copies_Temp;
	CREATE VIEW Book_Copies (
		book_id,
		branch_id,
		no_of_copies
	) AS 
		SELECT 
			bs.book_id, 
			bs.branch_id, 
			COUNT(*) 

			FROM Book_Status AS bs
			GROUP BY bs.book_id, bs.branch_id
			ORDER BY bs.book_id, bs.branch_id;
		
		
	CREATE OR REPLACE FUNCTION Add_New_Books(_book_id INT, _branch_id INT, _old_no_of_copies INT, _new_no_of_copies INT) RETURNS VOID AS $$
		DECLARE _copy INT;
		BEGIN
			FOR _copy in (_old_no_of_copies + 1) .. _new_no_of_copies LOOP
				INSERT INTO Book_Status (book_id, branch_id)
						VALUES (_book_id, _branch_id);
			END LOOP;
		END;
	$$ LANGUAGE plpgsql;
	
	CREATE OR REPLACE FUNCTION Update_Book_Copies() RETURNS TRIGGER AS $$
		DECLARE _copy INT;
		BEGIN 
			IF TG_OP = 'INSERT' THEN
				FOR _copy IN 1..NEW.no_of_copies LOOP 
					INSERT INTO Book_Status (book_id, branch_id)
						VALUES (NEW.book_id, NEW.branch_id);
				END LOOP;
			ELSEIF TG_OP = 'DELETE' THEN
				DELETE FROM Book_Status AS bs
					WHERE bs.book_id = OLD.book_id AND bs.branch_id = OLD.branch_id;
			ELSEIF TG_OP = 'UPDATE' THEN
				IF OLD.no_of_copies > NEW.no_of_copies THEN
					RETURN NULL;
				ELSE 
					UPDATE Book_Status AS bs SET 
					book_id = NEW.book_id,
					branch_id = NEW.branch_id
					WHERE bs.book_id = OLD.book_id AND
						bs.branch_id = OLD.branch_id;
																					-- nao sei mas no_of_copies esta vindo como bigint
					PERFORM Add_New_Books(NEW.book_id, NEW.branch_id, OLD.no_of_copies::INT, NEW.no_of_copies::INT);
				END IF;
			END IF;
			RETURN NULL;
		END;
	$$ LANGUAGE plpgsql;
	
	CREATE OR REPLACE TRIGGER TG_Update_Book_Copies
		INSTEAD OF INSERT OR
				UPDATE OR
				DELETE ON Book_Copies
		FOR EACH ROW EXECUTE PROCEDURE Update_Book_Copies();
		

	
	SELECT * FROM Book_Copies;
	SELECT * FROM Book_Status;
	DELETE FROM Book_Copies WHERE book_id = 1 AND branch_id = 1;
	INSERT INTO Book_Copies (book_id, branch_id, no_of_copies) VALUES (1, 1, 10);
	
	UPDATE Book_Copies SET no_of_copies = 14 WHERE book_id = 2 AND branch_id = 1;
	
ROLLBACK;