-- Banco de dados da Clínica Veterinária Pata Amiga (dados fictícios para laboratório).
-- Este script é executado automaticamente na inicialização do contêiner do PostgreSQL.

-- Criação da tabela de tutores (proprietários dos animais)
CREATE TABLE tutores (
    id SERIAL PRIMARY KEY,
    nome TEXT NOT NULL,
    telefone TEXT
);

-- Criação da tabela de pacientes (animais atendidos na clínica)
CREATE TABLE pacientes (
    id SERIAL PRIMARY KEY,
    nome TEXT NOT NULL,
    especie TEXT NOT NULL,
    tutor_id INTEGER NOT NULL REFERENCES tutores(id)
);

-- Criação da tabela de consultas agendadas e realizadas
CREATE TABLE consultas (
    id SERIAL PRIMARY KEY,
    paciente_id INTEGER NOT NULL REFERENCES pacientes(id),
    data_hora TIMESTAMP NOT NULL
);

-- Criação da tabela de prontuários médicos (dados clínicos sigilosos de acesso restrito ao médico veterinário)
CREATE TABLE prontuarios (
    id SERIAL PRIMARY KEY,
    paciente_id INTEGER NOT NULL REFERENCES pacientes(id),
    diagnostico TEXT NOT NULL,
    prescricao TEXT
);

-- Inserção de dados iniciais fictícios para testes de validação
INSERT INTO tutores (nome, telefone) VALUES
    ('Tutor Exemplo 1', '(00) 00000-0001'),
    ('Tutor Exemplo 2', '(00) 00000-0002'),
    ('Tutor Exemplo 3', '(00) 00000-0003');

INSERT INTO pacientes (nome, especie, tutor_id) VALUES
    ('Thor', 'cao', 1),
    ('Mel', 'gato', 2),
    ('Bidu', 'cao', 3);

INSERT INTO consultas (paciente_id, data_hora) VALUES
    (1, '2026-10-20 09:00'),
    (2, '2026-10-20 10:00'),
    (3, '2026-10-21 14:30');

INSERT INTO prontuarios (paciente_id, diagnostico, prescricao) VALUES
    (1, 'Otite externa', 'Gotas auriculares por 7 dias'),
    (2, 'Gengivite leve', 'Higiene bucal e retorno em 30 dias'),
    (3, 'Controle de peso', 'Ajuste de dieta e retorno em 60 dias');
