BEGIN;

	CREATE GLOBAL TEMPORARY TABLE Book_Copies_Temp AS (
		SELECT * FROM Felipe.Book_Copies
	
	);
	DROP TABLE Felipe.Book_Copies;

		
	-- Nao tive muitas ideias para o nome da tabela, entao decidi book_status
	-- por causa da condicao do livro
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
	
	CREATE OR REPLACE FUNCTION Felipe.Check_Copy_Inconsistencies(_book_id INT, _branch_id INT) RETURNS INT AS $$
		DECLARE copies_book_copies INT;
		DECLARE copies_book_status INT;
		BEGIN
			-- Acho que e otimizavel, mas nao cheguei a tentar
			copies_book_status := COUNT(*) FROM Felipe.Book_Status AS bs
									WHERE bs.book_id = _book_id AND 
									bs.branch_id = _branch_id;
										
			copies_book_copies := bc.no_of_copies FROM Book_Copies_Temp AS bc
									WHERE bc.book_id = _book_id AND 
									bc.branch_id = _branch_id;
										
			RETURN copies_book_copies - copies_book_status;
		END;
		
	$$ LANGUAGE plpgsql;
		
	-- Pensei em usar cursor pra fazer a parte de consertar as inconsistencias
	-- mas usar uma tabela temporaria pareceu mais facil de fazer e abstrair
	CREATE TEMPORARY TABLE Copy_Inconsistencies (
		book_id INT NOT NULL,
		branch_id INT NOT NULL,
		copies_diff INT NOT NULL
	);
	
	CREATE OR REPLACE FUNCTION Felipe.Get_Copies_Inconsistencies() RETURNS SETOF Copy_Inconsistencies AS $$
		BEGIN
			RETURN QUERY 
				SELECT bc.book_id, bc.branch_id, Felipe.Check_Copy_Inconsistencies(bc.book_id, bc.branch_id) 
					FROM Book_Copies_Temp AS bc 
					WHERE Felipe.Check_Copy_Inconsistencies(bc.book_id, bc.branch_id) <> 0;
		END;
		
	$$ LANGUAGE plpgsql;

  	CREATE OR REPLACE PROCEDURE Felipe.Fix_Copy_Inconsistencies(_copy Copy_Inconsistencies) LANGUAGE plpgsql AS $$
		DECLARE book INT;
		BEGIN
			FOR book IN 1.._copy.copies_diff LOOP
                	INSERT INTO Felipe.Book_Status (book_id, branch_id) VALUES (_copy.book_id, _copy.branch_id);
			END LOOP;
		END;
		
	$$;
	
	CREATE OR REPLACE PROCEDURE Felipe.Remove_Copies_Inconsistencies() LANGUAGE plpgsql AS $$
        DECLARE _copy Copy_Inconsistencies;
        BEGIN
            FOR _copy IN SELECT * FROM Felipe.Get_Copies_Inconsistencies() LOOP
                CALL Felipe.Fix_Copy_Inconsistencies(_copy);
            END LOOP;
        END;
		
	$$;
	
	CALL Felipe.Remove_Copies_Inconsistencies();

	-- Como as funcoes e procedimentos foram feitas com o proposito de fazer
	-- uma transicao de sistema, entao acho que faz sentido dropar elas depois
	DROP PROCEDURE Felipe.Remove_Copies_Inconsistencies;
	DROP PROCEDURE Felipe.Fix_Copy_Inconsistencies;
	DROP FUNCTION Felipe.Get_Copies_Inconsistencies;
	DROP TABLE Copy_Inconsistencies;


	-- Alterando tabelas conforme pedido
	ALTER TABLE Felipe.Book_Loans 
		ADD COLUMN book_status_id INT;
	ALTER TABLE Felipe.Book_Loans
		DROP CONSTRAINT PK_Book_Loans;
	ALTER TABLE Felipe.Book_Loans
		DROP CONSTRAINT FK_Book_Loans_Book;
	ALTER TABLE Felipe.Book_Loans
		DROP CONSTRAINT FK_Book_Loans_Branch;


	-- Acho que da pra notar que eu fiz funcao pra tudo, mas acho que
	-- fica mais facil de abstrair o que esta acontecendo

	-- Pega a primeira copia disponivel em determinado dia, retorna null se nao tiver
	CREATE OR REPLACE FUNCTION Felipe.Get_Available_Copy_Given_Day(_book_id INT, _branch_id INT, _day DATE) RETURNS INT AS $$
		BEGIN
			RETURN 
				(SELECT bs.book_status_id 
					FROM Felipe.Book_Status AS bs
					WHERE bs.book_id = _book_id AND
						bs.branch_id = _branch_id AND
						bs.book_status_id NOT IN 
							(SELECT bl.book_status_id 
								FROM Felipe.Book_Loans AS bl
								WHERE bl.book_id = _book_id AND
								bl.branch_id = _branch_id AND
								bl.date_out <= _day AND
								bl.due_date >= _day AND
								book_status_id IS NOT NULL)
									
					LIMIT 1);
		
		END;
		
	$$ LANGUAGE plpgsql;
		
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