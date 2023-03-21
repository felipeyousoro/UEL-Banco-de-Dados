BEGIN;

	CREATE OR REPLACE FUNCTION Levenshtein(str1 VARCHAR, str2 VARCHAR) RETURNS INT AS $$
		DECLARE
			len1 int := LENGTH(str1);
			len2 int := LENGTH(str2);
			d int[][] := array_fill(0, ARRAY[len1 + 1, len2 + 1]);
			i int;
			j int;
		BEGIN
			IF len1 = 0 THEN
				RETURN len2;
			ELSIF len2 = 0 THEN
				RETURN len1;
			END IF;

			FOR i IN 1..len1 LOOP
				d[i+1][1] := i;
			END LOOP;

			FOR j IN 1..len2 LOOP
				d[1][j+1] := j;
			END LOOP;

			FOR j IN 2..len2+1 LOOP
				FOR i IN 2..len1+1 LOOP
					IF SUBSTRING(str1, i-1, 1) = SUBSTRING(str2, j-1, 1) THEN
						d[i][j] := d[i-1][j-1];
					ELSE
						d[i][j] := LEAST(d[i-1][j], d[i][j-1], d[i-1][j-1]) + 1;
					END IF;
				END LOOP;
			END LOOP;

			RETURN d[len1+1][len2+1];

		END;
	$$ LANGUAGE plpgsql;	
	
	CREATE OR REPLACE FUNCTION Book_Loans.Get_Shortened_Middle_Name(_name VARCHAR) RETURNS VARCHAR AS $$
		BEGIN
			RETURN SUBSTRING(SPLIT_PART(_name, ' ', 2), 1, 1);
		END;
	$$ LANGUAGE plpgsql;

	CREATE OR REPLACE FUNCTION Book_Loans.Get_Shortened_Name(_name VARCHAR) RETURNS VARCHAR AS $$
		DECLARE 
			_first_name VARCHAR;
			_middle_name VARCHAR;
			_surname VARCHAR;
		BEGIN
			SELECT INTO _first_name, _middle_name, _surname
				SPLIT_PART(_name, ' ', 1),
				Book_Loans.Get_Shortened_Middle_Name(_name),
				SPLIT_PART(_name, ' ', 3);
			RETURN _first_name || ' ' || _middle_name || '. ' || _surname;

		END;
	$$ LANGUAGE plpgsql;
	
	CREATE TABLE Book_Loans.Book_Authors_Log (
		book_id INT NOT NULL,
		new_author_name VARCHAR(255) NOT NULL,
		old_author_name VARCHAR(255) NOT NULL,
		update_timestamp TIMESTAMP NOT NULL DEFAULT NOW()
	);

	CREATE FUNCTION Book_Loans.Log_Author_Update() RETURNS TRIGGER AS $$
		BEGIN
			INSERT INTO Book_Loans.Book_Authors_Log (book_id, new_author_name, old_author_name)
				VALUES (NEW.book_id, NEW.author_name, OLD.author_name);
			RETURN NEW;
		END;
	$$ LANGUAGE plpgsql;

	CREATE TRIGGER Log_Author_Update
		AFTER UPDATE ON Book_Loans.Book_Authors
		FOR EACH ROW
		WHEN (OLD.author_name <> NEW.author_name)
		EXECUTE PROCEDURE Book_Loans.Log_Author_Update();


	CREATE PROCEDURE Book_Loans.Detect_And_Reconcile_Authors() LANGUAGE plpgsql AS $$
		DECLARE
			_record1 RECORD;
			_record2 RECORD;
			_author_name VARCHAR;
			_count INT;
			_count_sum INT;
			_cursor1 CURSOR FOR SELECT author_name FROM Book_Loans.Book_Authors FOR UPDATE;
		BEGIN 
			OPEN _cursor1;
			LOOP
				FETCH _cursor1 INTO _record1;
				
				EXIT WHEN NOT FOUND;
					SELECT author_name, COUNT(*) AS author_count
						INTO _author_name, _count
						FROM Book_Loans.Book_Authors
						WHERE Levenshtein(author_name, _record1.author_name) < 2 OR
							Levenshtein(Book_Loans.Get_Shortened_Name(author_name), Book_Loans.Get_Shortened_Name(_record1.author_name)) < 2 OR
							Book_Loans.Get_Shortened_Middle_Name(author_name) = Book_Loans.Get_Shortened_Middle_Name(_record1.author_name)
						GROUP BY author_name
						ORDER BY author_count DESC
						LIMIT 1;
						
						SELECT SUM(_count) INTO _count_sum;

					UPDATE Book_Loans.Book_Authors 
						SET author_name = _author_name
						WHERE Levenshtein(author_name, _author_name) < 2 OR
							Levenshtein(Book_Loans.Get_Shortened_Name(author_name), Book_Loans.Get_Shortened_Name(_record1.author_name)) < 2 OR
							Book_Loans.Get_Shortened_Middle_Name(author_name) = Book_Loans.Get_Shortened_Middle_Name(_record1.author_name);


			END LOOP;
			CLOSE _cursor1;
		END;
	$$;
	
	CALL Book_Loans.Detect_And_Reconcile_Authors();
	SELECT * FROM Book_Loans.Book_Authors;
	SELECT * FROM Book_Loans.Book_Authors_Log;
	
 		SELECT author_name, COUNT(*) AS author_count
 				FROM Book_Loans.Book_Authors
 				WHERE Levenshtein(author_name, 'John J. Powell') < 2 OR
 					Levenshtein(Book_Loans.Get_Shortened_Name(author_name), Book_Loans.Get_Shortened_Name('John J. Powell')) < 2 OR --possivelmente and aqui
 					Book_Loans.Get_Shortened_Middle_Name(author_name) = Book_Loans.Get_Shortened_Middle_Name('John J. Powell')
 				GROUP BY author_name
 				ORDER BY author_count DESC;
		
 		UPDATE Book_Loans.Book_Authors 
 			SET author_name = 'John J. Powell'
 			WHERE Levenshtein(author_name, 'John J. Powell') < 2 OR
 			Levenshtein(Book_Loans.Get_Shortened_Name(author_name), Book_Loans.Get_Shortened_Name('John J. Powell')) < 2 OR
 			Book_Loans.Get_Shortened_Middle_Name(author_name) = Book_Loans.Get_Shortened_Middle_Name('John J. Powell');



ROLLBACK;
