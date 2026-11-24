# evo-service-crm

Modelo genérico para serviços online e negócios de serviço. Usa as stacks, imagens, configuração e patch compartilhados em `crm/evo-jud-crm/`; os nomes das imagens mantêm a referência ao projeto jurídico. O wizard preserva esse caminho do patch para compatibilidade.

O template `templates/servicos.rb` cria, quando ainda não existem:

- Pipeline Comercial: Novo lead, Qualificado, Proposta enviada, Negociação, Ganho e Perdido.
- Pipeline Pós-venda e recompra: Cliente ativo, Acompanhamento, Pedido de indicação e Recompra.
- Pipeline Prospecção (separado do Comercial; ativa, só pela API oficial do WhatsApp e só para lista com opt-in): Lista com opt-in, Primeiro contato enviado, Respondeu, Qualificado, Passou para o comercial, Sem interesse e Não contatar.
- Etiquetas de atendimento e origem, incluindo opt-out, prospeccao e opt-in; campos de origem do lead, serviço de interesse, orçamento estimado, próxima ação, consentimento e não contatar.
- Macros de boas-vindas, pedido de orçamento, follow-up e pós-venda; automação de opt-out por mensagem.
- Configuração do funil de tráfego: Qualificado representa reunião/qualificação e Ganho ou Cliente ativo representam contrato/venda; WhatsApp e links de agenda são opcionais.

O template é idempotente por nome e não sobrescreve itens existentes. `BRITTO_DRY_RUN=1` no Rails executa em transação revertida. Revise os textos e as etapas de tracking para adequá-los ao processo do negócio.
