# Ecommerce

## Descrição

Este projeto implementa um sistema de e-commerce com integração entre Python e MySQL, simulando o funcionamento básico de uma plataforma de vendas online.  
O sistema foi desenvolvido com foco em organização de dados relacionais, operações CRUD (Create, Read, Update, Delete) e interação via terminal.

##  Estrutura geral do projeto

| `Codigoecommerce.sql` | Contém a criação do banco de dados ecommerce, tabelas e inserções iniciais. 


| `codigopythonecommerce.py` | Código principal em Python com as operações de consulta, inserção, atualização e exclusão de dados. 


| `conexao.py` | Script responsável por estabelecer a conexão com o servidor MySQL. 


| `README.md` | Documento de explicação e instruções do projeto. 

## Estrutura do banco de dados utilizado

O banco de dados ecommerce contém tabelas principais que representam as entidades básicas de um comércio eletrônico.  
Entre elas são os clientes, produtos, pedidos, itens_pedido e categorias.
Essas tabelas possuem chaves primárias, estrangeiras e relacionamentos bem definidos, garantindo integridade referencial.

## Tecnologias Utilizadas

 **MySQL** —> Sistema de Gerenciamento de Banco de Dados Relacional  
**Python 3.x** —> Linguagem de programação usada para interação com o banco  
 **Biblioteca:** `mysql.connector` (nativa do pacote `mysql-connector-python`)  
 **Ambiente de desenvolvimento:** XAMPP / LAMPP (para o servidor local)

