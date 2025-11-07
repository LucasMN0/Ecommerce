-- 0) CRIAÇÃO / REINICIALIZAÇÃO DO BANCO
DROP DATABASE IF EXISTS ecommerce;
CREATE DATABASE ecommerce;
USE ecommerce;


-- ===============================================
-- 1) TABELAS
-- ===============================================

CREATE TABLE cliente (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(50) NOT NULL,
    idade INT,
    sexo CHAR(1) CHECK (sexo IN ('m', 'f', 'o')),
    data_nascimento DATE
);

CREATE TABLE cliente_especial (
    id_cliente INT PRIMARY KEY,
    cashback DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    FOREIGN KEY (id_cliente) REFERENCES cliente(id) ON DELETE CASCADE
);

CREATE TABLE vendedor (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(50) NOT NULL,
    causa_social VARCHAR(100),
    tipo VARCHAR(50),
    nota_media DECIMAL(3,2) DEFAULT 0.00,
    salario DECIMAL(10,2) NOT NULL
);

CREATE TABLE funcionario_especial(
    id INT PRIMARY KEY AUTO_INCREMENT,
    id_vendedor INT UNIQUE,
    bonus DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    FOREIGN KEY (id_vendedor) REFERENCES vendedor(id) ON DELETE CASCADE
);

CREATE TABLE produto (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(50),
    descricao TEXT,
    quantidade_estoque INT NOT NULL,
    valor DECIMAL(10,2) NOT NULL,
    observacoes TEXT,
    id_vendedor INT,
    FOREIGN KEY (id_vendedor) REFERENCES vendedor(id)
);

CREATE TABLE transportadora (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(50),
    cidade VARCHAR(50)
);

CREATE TABLE transporte (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_transportadora INT,
    id_venda INT,
    valor DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    FOREIGN KEY (id_transportadora) REFERENCES transportadora(id)
);

CREATE TABLE log_bonus (
    id INT AUTO_INCREMENT PRIMARY KEY,
    mensagem VARCHAR(255),
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE venda (
    id INT PRIMARY KEY AUTO_INCREMENT,
    data_venda DATE,
    hora_venda TIME,
    valor DECIMAL(10,2),
    endereco VARCHAR(100),
    id_cliente INT,
    id_transporte INT,
    FOREIGN KEY (id_cliente) REFERENCES cliente(id),
    FOREIGN KEY (id_transporte) REFERENCES transporte(id)
    
);

CREATE TABLE venda_produto(
    id INT PRIMARY KEY AUTO_INCREMENT,
    id_venda INT,
    id_produto INT,
    qtd INT NOT NULL DEFAULT 1,
    valor DECIMAL(10, 2) NOT NULL,
    obs VARCHAR(100),
    FOREIGN KEY (id_venda) REFERENCES venda(id),
    FOREIGN KEY (id_produto) REFERENCES produto(id)
);
CREATE TABLE log_cashback (
    id INT AUTO_INCREMENT PRIMARY KEY,
    mensagem VARCHAR(255),
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE voucher (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT,
    valor DECIMAL(10,2),
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_cliente) REFERENCES cliente(id)
);

-- ===============================================
-- 2) FUNÇÕES
-- ===============================================

DELIMITER $$

-- Calcula_idade(cliente_id)
CREATE FUNCTION Calcula_idade(cliente_id INT)
RETURNS INT
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE nasc DATE;
    DECLARE idade INT;
    SELECT data_nascimento INTO nasc FROM cliente WHERE id = cliente_id;
    SET idade = TIMESTAMPDIFF(YEAR, nasc, CURDATE());
    RETURN idade;
END$$

-- Soma_fretes(destino) 

-- Arrecadado(data, id_vendedor)
CREATE FUNCTION Arrecadado(p_data DATE, p_id_vendedor INT)
RETURNS DECIMAL(10,2)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE total DECIMAL(10,2);
    SELECT IFNULL(SUM(vp.valor),0) INTO total
    FROM venda_produto vp
    JOIN produto p ON vp.id_produto = p.id
    JOIN venda v ON v.id = vp.id_venda
    WHERE v.data_venda = p_data AND p.id_vendedor = p_id_vendedor;
    RETURN total;
END$$

DELIMITER ;

-- ===============================================
-- 3) TRIGGERS
-- ===============================================

DELIMITER $$

-- 3.1 Trigger: vendedor_especial
CREATE TRIGGER trg_vendedor_especial
AFTER INSERT ON venda_produto
FOR EACH ROW
BEGIN
    DECLARE total_vendas DECIMAL(10,2);
    DECLARE bonus_total DECIMAL(10,2);
    DECLARE vendedor_id INT;

    SELECT id_vendedor INTO vendedor_id FROM produto WHERE id = NEW.id_produto;

    SELECT SUM(vp.valor)
    INTO total_vendas
    FROM venda_produto vp
    JOIN produto p ON vp.id_produto = p.id
    WHERE p.id_vendedor = vendedor_id;

    IF total_vendas > 1000 THEN
        SET bonus_total = total_vendas * 0.05;
        INSERT INTO funcionario_especial (id_vendedor, bonus)
        VALUES (vendedor_id, bonus_total)
        ON DUPLICATE KEY UPDATE bonus = bonus_total;

        INSERT INTO log_bonus (mensagem)
        VALUES (CONCAT('Bônus total necessário para custear: R$ ', ROUND(bonus_total,2)));
    END IF;
END$$

-- 3.2 Trigger: cliente_especial
CREATE TRIGGER trg_cliente_especial
AFTER INSERT ON venda
FOR EACH ROW
BEGIN
    DECLARE total_cliente DECIMAL(10,2);
    DECLARE cashback_total DECIMAL(10,2);

    SELECT SUM(valor)
    INTO total_cliente
    FROM venda
    WHERE id_cliente = NEW.id_cliente;

    IF total_cliente > 500 THEN
        SET cashback_total = total_cliente * 0.02;
        INSERT INTO cliente_especial (id_cliente, cashback)
        VALUES (NEW.id_cliente, cashback_total)
        ON DUPLICATE KEY UPDATE cashback = cashback_total;

        INSERT INTO log_cashback (mensagem)
        VALUES (CONCAT('Cashback total necessário: R$ ', ROUND(cashback_total,2)));
    END IF;
END$$

-- 3.3 Trigger: remover cliente especial com cashback zerado
CREATE TRIGGER trg_remove_cliente_especial
AFTER UPDATE ON cliente_especial
FOR EACH ROW
BEGIN
    IF NEW.cashback = 0 THEN
        DELETE FROM cliente_especial WHERE id_cliente = NEW.id_cliente;
    END IF;
END$$

DELIMITER ;

-- ===============================================
-- 4) PROCEDURES
-- ===============================================

DELIMITER $$

-- Reajuste salarial
CREATE PROCEDURE Reajuste(p_percentual DECIMAL(5,2))
BEGIN
    UPDATE vendedor
    SET salario = salario + (salario * p_percentual / 100);
END$$

-- Sorteio de cliente
DELIMITER $$
CREATE PROCEDURE Sorteio()
proc_label: BEGIN
    DECLARE v_id_cliente INT;

    SELECT id INTO v_id_cliente 
    FROM cliente 
    ORDER BY RAND() 
    LIMIT 1;

    IF v_id_cliente IS NULL THEN
        SELECT 'Sem clientes para sortear.' AS mensagem;
        LEAVE proc_label;
    END IF;

    IF EXISTS (SELECT 1 FROM cliente_especial WHERE id_cliente = v_id_cliente) THEN
        INSERT INTO voucher (id_cliente, valor) VALUES (v_id_cliente, 200.00);
        SELECT v_id_cliente AS cliente_sorteado, 200.00 AS valor_voucher;
    ELSE
        INSERT INTO voucher (id_cliente, valor) VALUES (v_id_cliente, 100.00);
        SELECT v_id_cliente AS cliente_sorteado, 100.00 AS valor_voucher;
    END IF;
END$$
DELIMITER ;
DELIMITER $$
-- Venda: reduz estoque
CREATE PROCEDURE Venda(p_id_produto INT, p_qtd INT, p_id_cliente INT, p_endereco VARCHAR(100))
BEGIN
    DECLARE v_valor DECIMAL(10,2);
    SELECT valor INTO v_valor FROM produto WHERE id = p_id_produto;

    INSERT INTO venda (data_venda, hora_venda, valor, endereco, id_cliente)
    VALUES (CURDATE(), CURTIME(), v_valor * p_qtd, p_endereco, p_id_cliente);

    UPDATE produto SET quantidade_estoque = quantidade_estoque - p_qtd WHERE id = p_id_produto;
END$$

-- Estatísticas
CREATE PROCEDURE Estatisticas()
BEGIN
    SELECT 
        p.nome AS produto,
        SUM(vp.qtd) AS total_vendido,
        SUM(vp.valor) AS total_ganho
    FROM venda_produto vp
    JOIN produto p ON vp.id_produto = p.id
    GROUP BY p.id
    ORDER BY total_vendido DESC;
END$$

DELIMITER ;

-- ===============================================
-- 5) USUÁRIOS E PERMISSÕES
-- ===============================================

CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY 'Senhateste1!';
GRANT ALL PRIVILEGES ON ecommerce.* TO 'admin'@'%';

CREATE USER IF NOT EXISTS 'gerente'@'%' IDENTIFIED BY 'Senhateste1!';
GRANT SELECT, UPDATE, DELETE ON ecommerce.* TO 'gerente'@'%';
CREATE USER IF NOT EXISTS 'funcionario'@'%' IDENTIFIED BY 'Senhateste1!';
GRANT INSERT, SELECT ON ecommerce.venda TO 'funcionario'@'%';
GRANT INSERT, SELECT ON ecommerce.venda_produto TO 'funcionario'@'%';
GRANT INSERT, SELECT ON ecommerce.produto TO 'funcionario'@'%';
GRANT SELECT ON ecommerce.cliente TO 'funcionario'@'%';
GRANT EXECUTE ON ecommerce.* TO 'funcionario'@'%';
FLUSH PRIVILEGES;

-- ===============================================
-- 6) INSERÇÕES DE TESTE (opcional)
-- ===============================================

INSERT INTO vendedor (nome, salario) VALUES 
('João Gabriel', 1500.00),
('Maria Silva', 1800.00);

INSERT INTO cliente (nome, idade, sexo, data_nascimento)
VALUES ('Lucas', 20, 'm', '2004-12-05');

INSERT INTO produto (nome, valor, quantidade_estoque, id_vendedor)
VALUES ('Biscoito', 100.00, 10, 1);

INSERT INTO venda (data_venda, hora_venda, valor, endereco, id_cliente)
VALUES (CURDATE(), CURTIME(), 100.00, 'Recife', 1);

-- Teste de funções
SELECT Calcula_idade(1) AS idade_cliente;

SELECT Arrecadado(CURDATE(),1) AS total_arrecadado;
INSERT INTO transportadora(nome,cidade) VALUES ("Socorro",'Jesus');
INSERT INTO transporte(valor) VALUES (100.00);
DESCRIBE produto;


