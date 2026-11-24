# britto-wizard · template "servicos" para o evo-service-crm.
# Roda dentro do container do CRM:  bundle exec rails runner /tmp/template.rb
# Idempotente: procura pelo nome antes de criar; nada é apagado nem sobrescrito.
# Parâmetros por variável de ambiente (o wizard passa):
#   BRITTO_ORG_NAME, BRITTO_WHATSAPP (só dígitos, com DDI), BRITTO_SCHEDULING_URLS (vírgula),
#   BRITTO_DRY_RUN=1 (cria tudo numa transação e desfaz no fim: só valida).

ORG = ENV.fetch('BRITTO_ORG_NAME', 'Meu negócio').strip
WHATSAPP = ENV.fetch('BRITTO_WHATSAPP', '').gsub(/\D/, '')
SCHEDULING = ENV.fetch('BRITTO_SCHEDULING_URLS', '').strip
DRY = ENV['BRITTO_DRY_RUN'] == '1'

author = User.where(type: 'SuperAdmin').order(:created_at).first || User.order(:created_at).first
abort('Crie a primeira conta no CRM antes de aplicar o template.') unless author

PIPELINES = [
  { name: 'Comercial', description: 'Do primeiro contato à venda.', stages: [
    ['Novo lead', '#94A3B8', :active, 'Novo contato recebido'],
    ['Qualificado', '#3B82F6', :active, 'Necessidade e interesse identificados'],
    ['Proposta enviada', '#8B5CF6', :active, 'Proposta enviada ao contato'],
    ['Negociação', '#F59E0B', :active, 'Condições em negociação'],
    ['Ganho', '#10B981', :completed, 'Venda concluída'],
    ['Perdido', '#9CA3AF', :cancelled, 'Venda não realizada']
  ] },
  { name: 'Pós-venda e recompra', description: 'Relacionamento após a venda.', stages: [
    ['Cliente ativo', '#10B981', :active, 'Serviço em andamento'],
    ['Acompanhamento', '#3B82F6', :active, 'Acompanhar resultados e satisfação'],
    ['Pedido de indicação', '#8B5CF6', :active, 'Solicitar indicação'],
    ['Recompra', '#F59E0B', :active, 'Identificar nova oportunidade']
  ] }
].freeze

LABELS = [
  ['aguardando-retorno', 'Aguardando resposta do contato', '#FBBF24'],
  ['bot-pausado', 'Atendimento humano assumiu', '#1F93FF'],
  ['cliente-ativo', 'Cliente com serviço em andamento', '#14B8A6'],
  ['equipe', 'Contato interno', '#0EA5E9'],
  ['fora-do-escopo', 'Serviço fora do escopo', '#6B7280'],
  ['opt-out', 'Pediu para não receber mensagens', '#DC2626'],
  ['prioridade-humano', 'Precisa de atendimento humano', '#B91C1C'],
  ['origem-meta', 'Anúncio do Meta', '#1877F2'],
  ['origem-google', 'Anúncio do Google', '#34A853'],
  ['origem-site', 'Site', '#0F766E'],
  ['origem-instagram', 'Instagram orgânico', '#C13584'],
  ['origem-postiz', 'Publicação pelo Postiz', '#7C3AED'],
  ['origem-openreply', 'DM automática do OpenReply', '#9333EA']
].freeze

ATTRIBUTES = [
  ['Origem do lead', 'origem_lead', :text, []],
  ['Serviço de interesse', 'servico_interesse', :text, []],
  ['Orçamento estimado', 'orcamento_estimado', :text, []],
  ['Próxima ação', 'proxima_acao', :text, []],
  ['Consentimento LGPD (data/hora)', 'consentimento_lgpd', :datetime, []],
  ['Não contatar (opt-out)', 'nao_contatar', :checkbox, []]
].freeze

created = Hash.new(0)

ActiveRecord::Base.transaction do
  PIPELINES.each do |pd|
    pipeline = Pipeline.find_by(name: pd[:name])
    unless pipeline
      pipeline = Pipeline.create!(name: pd[:name], description: pd[:description], created_by_id: author.id,
                                  pipeline_type: 'custom', visibility: :public, is_active: true)
      created[:pipelines] += 1
    end
    pd[:stages].each_with_index do |(name, color, type, desc), i|
      next if pipeline.pipeline_stages.exists?(name: name)

      pipeline.pipeline_stages.create!(name: name, color: color, stage_type: type, position: i + 1,
                                       automation_rules: desc.present? ? { 'description' => desc } : {})
      created[:stages] += 1
    end
  end

  LABELS.each do |title, description, color|
    next if Label.exists?(title: title)

    Label.create!(title: title, description: description, color: color, show_on_sidebar: true)
    created[:labels] += 1
  end

  ATTRIBUTES.each do |display, key, type, values|
    next if CustomAttributeDefinition.exists?(attribute_key: key, attribute_model: :contact_attribute)

    CustomAttributeDefinition.create!(attribute_display_name: display, attribute_description: display, attribute_key: key,
                                      attribute_display_type: type, attribute_model: :contact_attribute,
                                      attribute_values: values)
    created[:attributes] += 1
  end

  macros = [
    ['Boas-vindas', [{ 'action_name' => 'send_message', 'action_params' => ["Olá! Boas-vindas à #{ORG}. Como podemos ajudar?"] }]],
    ['Pedir orçamento', [{ 'action_name' => 'send_message', 'action_params' => ['Conte sobre o serviço que procura e seu orçamento estimado.'] }]],
    ['Follow-up', [{ 'action_name' => 'send_message', 'action_params' => ['Olá! Gostaria de saber se conseguiu avaliar nossa proposta. Podemos ajudar?'] }]],
    ['Pós-venda', [{ 'action_name' => 'send_message', 'action_params' => ['Olá! Como foi sua experiência com nosso serviço? Conte com a gente.'] }]]
  ]
  macros.each do |name, actions|
    next if Macro.exists?(name: name)

    Macro.create!(name: name, visibility: :global, created_by_id: author.id, updated_by_id: author.id, actions: actions)
    created[:macros] += 1
  end

  unless AutomationRule.exists?(name: 'Opt-out · Sair/Parar')
    AutomationRule.create!(
      name: 'Opt-out · Sair/Parar',
      description: 'Contato pediu para parar: marca "não contatar" e aplica a etiqueta opt-out.',
      event_name: 'message_created', active: true, mode: 'simple',
      conditions: [
        { 'values' => ['0'], 'attribute_key' => 'message_type', 'query_operator' => 'AND', 'filter_operator' => 'equal_to' },
        { 'values' => %w[sair Sair SAIR parar Parar PARAR pare Pare stop] + ['cancelar avisos'],
          'attribute_key' => 'content', 'filter_operator' => 'equal_to' }
      ],
      actions: [
        { 'action_name' => 'update_custom_attribute',
          'action_params' => [{ 'custom_attribute_key' => 'nao_contatar', 'custom_attribute_model' => 'contact_attribute',
                                'custom_attribute_value' => 'true' }] },
        { 'action_name' => 'add_label', 'action_params' => ['opt-out'] }
      ]
    )
    created[:automations] += 1
  end

  # Funil de tráfego: quais etapas representam qualificação e venda; número do WhatsApp; links de agenda.
  if defined?(Tracking::Config)
    stage = ->(pipe, name) { Pipeline.find_by(name: pipe)&.pipeline_stages&.find_by(name: name)&.id }
    {
      'TRACKING_STAGE_MEETING_IDS' => [stage.call('Comercial', 'Qualificado')],
      'TRACKING_STAGE_CONTRACT_IDS' => [stage.call('Comercial', 'Ganho'), stage.call('Pós-venda e recompra', 'Cliente ativo')]
    }.each do |key, ids|
      next if GlobalConfigService.load(key, nil).present?

      GlobalConfig.set(key, ids.compact.join(','))
      created[:tracking] += 1
    end
    if WHATSAPP.present? && GlobalConfigService.load('TRACKING_WHATSAPP_NUMBER', nil).blank?
      GlobalConfig.set('TRACKING_WHATSAPP_NUMBER', WHATSAPP)
      created[:tracking] += 1
    end
    if SCHEDULING.present? && GlobalConfigService.load('TRACKING_SCHEDULING_URLS', nil).blank?
      GlobalConfig.set('TRACKING_SCHEDULING_URLS', SCHEDULING)
      created[:tracking] += 1
    end
  end

  if DRY
    puts "DRY-RUN ok (nada gravado): #{created.to_h}"
    raise ActiveRecord::Rollback
  end
end

unless DRY
  GlobalConfig.clear_cache if GlobalConfig.respond_to?(:clear_cache)
  puts "Template de serviços aplicado: #{created.to_h} (itens já existentes foram mantidos)"
end
