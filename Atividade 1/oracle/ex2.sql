BEGIN;

	CREATE GLOBAL TEMPORARY TABLE Book_Copies_Temp
		ON COMMIT PRESERVE ROWS
		AS SELECT * FROM Felipe.Book_Copies;

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
	DROP PACKAGE Felipe.Copy_Inconsistencies_Pack;

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

		
	-- Feito para definir a copia que o usuario pegou em determinado dia
	-- essa funcao tambem e uma para a transicao do banco
	-- pois nao tem como saber qual copia o usuario pegou anteriormente
	CREATE OR REPLACE PROCEDURE Felipe.Add_Copy_Book_Loan(_loan Felipe.Book_Loans) LANGUAGE plpgsql AS $$
        BEGIN
            UPDATE Felipe.Book_Loans
				SET 
					book_status_id = Felipe.Get_Available_Copy_Given_Day(_loan.book_id, _loan.branch_id, _loan.date_out)
				WHERE
					book_id = _loan.book_id AND
					branch_id = _loan.branch_id AND
					card_no = _loan.card_no;
					
        END;
	$$;
	
	CREATE OR REPLACE PROCEDURE Felipe.Update_Book_Loans() LANGUAGE plpgsql AS $$
		DECLARE _loan Felipe.Book_Loans;
		BEGIN
			FOR _loan IN SELECT * FROM Felipe.Book_Loans LOOP
				CALL Felipe.Add_Copy_Book_Loan(_loan);
			END LOOP;
		END;
		
	$$;
	
	CALL Felipe.Update_Book_Loans();

	-- Feita a transicao, podemos dropar a funcao
	-- suponho que novos inserts seriam feitos pensando
	-- no id da copia
	DROP PROCEDURE Felipe.Update_Book_Loans;
	DROP PROCEDURE Felipe.Add_Copy_Book_Loan;
	

	-- Alterando tabelas conforme pedido
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
			FROM Felipe.Book_Status AS bs
			GROUP BY bs.book_id, bs.branch_id
			ORDER BY bs.book_id, bs.branch_id;
		

	
	-- Talvez nao seja o jeito mais inteligente de fazer
	-- mas ele perfeitamente corrige a diferenca de copias	
	CREATE OR REPLACE PROCEDURE Felipe.Add_New_Books(_book_id INT, _branch_id INT, _old_no_of_copies INT, _new_no_of_copies INT) LANGUAGE plpgsql AS $$
		DECLARE _copy INT;
		BEGIN
			FOR _copy in (_old_no_of_copies + 1) .. _new_no_of_copies LOOP
				INSERT INTO Felipe.Book_Status (book_id, branch_id)
					VALUES (_book_id, _branch_id);
			END LOOP;
		END;
	$$;
	
	CREATE OR REPLACE FUNCTION Felipe.Update_Book_Copies() RETURNS TRIGGER AS $$
		DECLARE _copy INT;
		BEGIN 
			IF TG_OP = 'INSERT' THEN
				-- Adicionou novas copias entao elas devem ser registradas individualmente
				FOR _copy IN 1..NEW.no_of_copies LOOP 
					INSERT INTO Felipe.Book_Status (book_id, branch_id)
						VALUES (NEW.book_id, NEW.branch_id);
				END LOOP;
			ELSEIF TG_OP = 'DELETE' THEN
				-- Deletando todas copias
				-- Acredito que nao devemos alterar tambem a tabela de emprestimos
				DELETE FROM Felipe.Book_Status AS bs
					WHERE bs.book_id = OLD.book_id AND 
					bs.branch_id = OLD.branch_id;
			ELSEIF TG_OP = 'UPDATE' THEN
				-- Alteracoes de copias na view reduzindo o numero de copias
				-- NAO devem ser permitidas, entao ha um early return
				IF OLD.no_of_copies > NEW.no_of_copies THEN
					RETURN NULL;
				ELSE 
				-- Atualizacao onde o numero de copias aumentou ou manteve o mesmo
				-- Depois de atualizar as copias existentes, ele adiciona as novas
					UPDATE Felipe.Book_Status AS bs SET 
						book_id = NEW.book_id,
						branch_id = NEW.branch_id
						WHERE bs.book_id = OLD.book_id AND
						bs.branch_id = OLD.branch_id;

					-- Infelizmente eu nao sei o que aconteceu aqui, pois no_of_copies esta vindo como BIGINT
					-- e nao como INT, entao eu tive que fazer um cast para INT
					CALL Felipe.Add_New_Books(NEW.book_id, NEW.branch_id, OLD.no_of_copies::INT, NEW.no_of_copies::INT);
				END IF;
			END IF;
			RETURN NULL;
		END;
	$$ LANGUAGE plpgsql;
	
	CREATE OR REPLACE TRIGGER TG_Update_Book_Copies
		INSTEAD OF INSERT OR
				UPDATE OR
				DELETE ON Felipe.Book_Copies
		FOR EACH ROW EXECUTE PROCEDURE Felipe.Update_Book_Copies();
			
ROLLBACK;