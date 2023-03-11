BEGIN;

	CREATE TEMPORARY TABLE Book_Copies_Temp AS (
		SELECT * FROM Book_Copies
	
	);
		
	CREATE TABLE Book_Status (
		id SERIAL NOT NULL,
		acquisition_date DATE NOT NULL DEFAULT CURRENT_DATE,
		current_condition VARCHAR(255) NOT NULL DEFAULT 'good',
        book_id INT NOT NULL,
		branch_id INT NOT NULL,

		CONSTRAINT PK_Book_Status PRIMARY KEY (id),
        CONSTRAINT FK_Book_Status_Branch FOREIGN KEY (branch_id) REFERENCES Library_Branch(branch_id),
		CONSTRAINT FK_Book_Status_Book FOREIGN KEY (book_id) REFERENCES Book(book_id),
		CONSTRAINT CHK_Book_Status_Current_Condition CHECK (current_condition IN ('fine', 'good', 'fair', 'poor'))
	
	);
	
	CREATE FUNCTION Check_Copy_Inconsistencies(_book_id INT, _branch_id INT) RETURNS INT AS $$
		DECLARE copies_book_copies INTEGER;
		DECLARE copies_book_status INTEGER;
		BEGIN
			copies_book_status := COUNT(*) FROM Book_Status AS bs
									WHERE bs.book_id = _book_id 
										AND bs.branch_id = _branch_id;
										
			copies_book_copies := bc.no_of_copies FROM Book_Copies AS bc
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
	
	CREATE FUNCTION Get_Copies_Inconsistencies() RETURNS SETOF Copy_Inconsistencies AS $$
		BEGIN
			RETURN QUERY SELECT bc.book_id, bc.branch_id, Check_Copy_Inconsistencies(bc.book_id, bc.branch_id) 
				FROM Book_Copies AS bc 
					WHERE Check_Copy_Inconsistencies(bc.book_id, bc.branch_id) <> 0;
		END;
		
	$$ LANGUAGE plpgsql;

  	CREATE FUNCTION Fix_Copy_Inconsistencies(_copy Copy_Inconsistencies) RETURNS VOID AS $$
		DECLARE book INT;
		BEGIN
			FOR book IN 1.._copy.copies_diff LOOP
                	INSERT INTO Book_Status (book_id, branch_id) VALUES (_copy.book_id, _copy.branch_id);
			END LOOP;
		END;
		
	$$ LANGUAGE plpgsql;
	
	CREATE FUNCTION Remove_Copies_Inconsistencies() RETURNS VOID AS $$
        DECLARE _copy Copy_Inconsistencies;
        BEGIN
            FOR _copy IN SELECT * FROM Get_Copies_Inconsistencies() LOOP
                PERFORM Fix_Copy_Inconsistencies(_copy);
            END LOOP;
        END;
		
	$$ LANGUAGE plpgsql;
	
	SELECT Remove_Copies_Inconsistencies();
	SELECT * FROM Book_Status;
	
ROLLBACK;
