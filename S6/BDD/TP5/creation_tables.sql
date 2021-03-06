-- reinitialisation
DROP TABLE IF EXISTS PERSONNE;
DROP TABLE IF EXISTS SOCIETE;
DROP TABLE IF EXISTS SALARIE;
DROP TABLE IF EXISTS ACTION;
DROP TABLE IF EXISTS HISTO_An_ACTIONNAIRE;
DROP TYPE IF EXISTS tPersonne;
DROP TYPE IF EXISTS tSociete;
DROP TRIGGER IF EXISTS beforeChangeAction ON ACTION;
DROP TRIGGER IF EXISTS afterInsertAction ON ACTION;
DROP TRIGGER IF EXISTS beforeInsertAction ON ACTION
---------------------------- creation des types et tables-----------------------

CREATE TYPE tPersonne as(
	NumSecu int,
	Nom varchar(20),
	Prenom varchar(40),
	Sexe Varchar(1),
	DateNaiss date
);

CREATE TABLE PERSONNE of tPersonne (primary key(NumSecu));

CREATE TYPE tSociete as(
	CodeSoc int,
	NomSoc varchar(40),
	Adresse varchar(100)
);

CREATE TABLE SOCIETE of tSociete (primary key(CodeSoc));

CREATE TABLE SALARIE(
	Personne tPersonne,
	Societe tSociete,
	Salaire int,
	primary key(Personne,Societe)
);

CREATE TABLE ACTION(
	Personne tPersonne,
	Societe tSociete,
	DateAct DATE,
	NbrAct int,
	typeAct varchar(20),
	primary key(Personne,Societe,DateAct)
);

CREATE TABLE HISTO_An_ACTIONNAIRE(
	Personne tPersonne,
	Societe tSociete,
	Annee int,
	NbrActTotal int,
	NbrAchat int,
	NbrVente int,
	primary key(Personne,Societe,Annee)
);

------------------------------ remplissage des tables---------------------------

INSERT INTO PERSONNE VALUES
	(001,'Nietzsche','Friedrich','h','1844-10-15'),
	(002,'Marx','Karl','h','1818-05-05'),
	(003,'Le Bon','Gustave','h','1841-05-07'),
	(004,'Freud','Sigmond','h','1856-05-06');

INSERT INTO SOCIETE VALUES
	(010,'Les Nouvelles Pensees','30 rue Yalontan'),
	(020,'Le Renouveau Allemand','2 rue ALaiste');

INSERT INTO SALARIE VALUES
	((SELECT P FROM PERSONNE P WHERE P.NumSecu= 001),(SELECT S FROM SOCIETE S WHERE S.NomSoc='Le Renouveau Allemand'),3000),
	((SELECT P FROM PERSONNE P WHERE P.NumSecu= 001),(SELECT S FROM SOCIETE S WHERE S.NomSoc='Les Nouvelles Pensees'),5000),
	((SELECT P FROM PERSONNE P WHERE P.NumSecu= 002),(SELECT S FROM SOCIETE S WHERE S.NomSoc='Le Renouveau Allemand'),3000),
	((SELECT P FROM PERSONNE P WHERE P.NumSecu= 002),(SELECT S FROM SOCIETE S WHERE S.NomSoc='Les Nouvelles Pensees'),5000),
	((SELECT P FROM PERSONNE P WHERE P.NumSecu= 003),(SELECT S FROM SOCIETE S WHERE S.NomSoc='Les Nouvelles Pensees'),5000),
	((SELECT P FROM PERSONNE P WHERE P.NumSecu= 004),(SELECT S FROM SOCIETE S WHERE S.NomSoc='Les Nouvelles Pensees'),5000);


----------------------- creation de triggers -----------------------------------
/*mise à jour de HISTO_An_ACTIONNAIRE quand ACTION a une insertion*/
CREATE OR REPLACE FUNCTION majHistoActionnaire() RETURNS TRIGGER AS $$
	BEGIN
		RAISE NOTICE 'modif histo'; -- ward, permet de savoir quand le trigger est activé
		/* creation du nuplet s'il n'est pas present dans la BDD */
		IF NOT EXISTS(SELECT * FROM HISTO_An_ACTIONNAIRE WHERE Societe=NEW.Societe and Personne=NEW.Personne and Annee=EXTRACT(year FROM NEW.DateAct))
			THEN INSERT INTO HISTO_An_ACTIONNAIRE VALUES(NEW.Personne,NEW.Societe,EXTRACT(year FROM NEW.DateAct),0,0,0);
		END IF;
		/* maj du nuplet */
		IF NEW.TypeAct='achat' THEN
			UPDATE HISTO_An_ACTIONNAIRE
				SET NbrActTotal=NbrActTotal+NEW.NbrAct,NbrAchat=NbrAchat+NEW.NbrAct
				WHERE Societe=NEW.Societe and Personne=NEW.Personne and  Annee=EXTRACT(year FROM NEW.DateAct);
		ELSIF NEW.TypeAct='vente'THEN
			UPDATE HISTO_An_ACTIONNAIRE
				SET NbrActTotal=NbrActTotal+NEW.NbrAct, NbrVente=NbrVente+NEW.NbrAct
				WHERE Societe=NEW.Societe and Personne=NEW.Personne and  Annee=EXTRACT(year FROM NEW.DateAct);
		ELSE RAISE EXCEPTION 'erreur lors de la maj de HISTO_An_ACTIONNAIRE';
		END IF;
		RETURN NEW;
	END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER afterInsertAction AFTER INSERT ON ACTION
FOR EACH ROW EXECUTE PROCEDURE majHistoActionnaire();

/*Verification que la date est correcte en cas d'INSERT et interdiction d'UPDATE*/
CREATE OR REPLACE FUNCTION verifDateEtUpdate() RETURNS TRIGGER AS $$
	DECLARE
		diffDates int=NEW.DateAct-current_date;
	BEGIN
		RAISE NOTICE 'date'; -- ward, permet de savoir quand le trigger est activé
		IF TG_OP='UPDATE' THEN RAISE EXCEPTION 'updates interdits';
		ELSE
			IF (diffDates<0) THEN RAISE EXCEPTION 'dates érronées';
			END IF;
		END IF;
		RETURN NEW;
	EXCEPTION WHEN RAISE_EXCEPTION
   		THEN RETURN NULL;
	END;
$$ LANGUAGE 'plpgsql';


CREATE TRIGGER beforeChangeAction BEFORE INSERT OR UPDATE ON ACTION
FOR EACH ROW EXECUTE PROCEDURE verifDateEtUpdate();

/*Avant une insertion dans ACTION, verifie le nombre d'actions de l'actionnaire*/
CREATE OR REPLACE FUNCTION verifNbAction() RETURNS TRIGGER AS $$
	BEGIN
		RAISE NOTICE 'quantity'; -- ward, permet de savoir quand le trigger est activé
		IF (COALESCE((SELECT H.NbrActTotal FROM HISTO_An_ACTIONNAIRE H WHERE NEW.Personne=H.Personne and EXTRACT(year FROM NEW.DateAct)=H.Annee),0)+NEW.NbrAct) <=3
			THEN RETURN NEW;
			ELSE RAISE EXCEPTION 'quantité limite atteinte';
		END IF;
	EXCEPTION WHEN RAISE_EXCEPTION
   		THEN RETURN NULL;
	END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER beforeInsertAction BEFORE INSERT ON ACTION
FOR EACH ROW EXECUTE PROCEDURE verifNbAction();
---------------------------------- tests ---------------------------------------

INSERT INTO ACTION VALUES
	((SELECT P FROM PERSONNE P WHERE P.NumSecu=001),(SELECT S FROM SOCIETE S WHERE S.NOMSOC='Le Renouveau Allemand'),'1988-07-4',5,'vente'),
	((SELECT P FROM PERSONNE P WHERE P.NumSecu=001),(SELECT S FROM SOCIETE S WHERE S.NOMSOC='Le Renouveau Allemand'),'2027-05-21',3,'achat'),
	((SELECT P FROM PERSONNE P WHERE P.NumSecu=003),(SELECT S FROM SOCIETE S WHERE S.NOMSOC='Le Renouveau Allemand'),'2027-08-10',2,'achat'),
	((SELECT P FROM PERSONNE P WHERE P.NumSecu=003),(SELECT S FROM SOCIETE S WHERE S.NOMSOC='Les Nouvelles Pensees'),'2027-08-10',1,'achat'),
	((SELECT P FROM PERSONNE P WHERE P.NumSecu=004),(SELECT S FROM SOCIETE S WHERE S.NOMSOC='Les Nouvelles Pensees'),'2027-08-09',1,'achat'),
	((SELECT P FROM PERSONNE P WHERE P.NumSecu=004),(SELECT S FROM SOCIETE S WHERE S.NOMSOC='Les Nouvelles Pensees'),'2027-08-10',1,'achat'),
	((SELECT P FROM PERSONNE P WHERE P.NumSecu=004),(SELECT S FROM SOCIETE S WHERE S.NOMSOC='Les Nouvelles Pensees'),'2027-08-11',1,'vente'),
	((SELECT P FROM PERSONNE P WHERE P.NumSecu=001),(SELECT S FROM SOCIETE S WHERE S.NOMSOC='Le Renouveau Allemand'),'2022-08-10',2,'vente'),
	((SELECT P FROM PERSONNE P WHERE P.NumSecu=001),(SELECT S FROM SOCIETE S WHERE S.NOMSOC='Le Renouveau Allemand'),'1998-05-22',8,'achat');

INSERT INTO ACTION VALUES
	((SELECT P FROM PERSONNE P WHERE P.NumSecu=004),(SELECT S FROM SOCIETE S WHERE S.NOMSOC='Les Nouvelles Pensees'),'2027-08-13',1,'achat'),
	((SELECT P FROM PERSONNE P WHERE P.NumSecu=002),(SELECT S FROM SOCIETE S WHERE S.NOMSOC='Les Nouvelles Pensees'),'2021-12-28',4,'achat');

UPDATE ACTION
	SET NbrAct=0 WHERE NbrAct>0;

SELECT * FROM HISTO_An_ACTIONNAIRE;
