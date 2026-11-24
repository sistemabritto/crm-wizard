#!/usr/bin/env python3
"""Verifica o contrato do template sem exigir um CRM instalado."""
import pathlib
import re
import unittest

SOURCE = (pathlib.Path(__file__).resolve().parents[1] / 'crm/evo-service-crm/templates/servicos.rb').read_text()

class TemplateServicosTest(unittest.TestCase):
    def test_pipelines(self):
        pipelines = SOURCE.split('PIPELINES = [', 1)[1].split('LABELS = [', 1)[0]
        blocos = re.split(r"\{ name: '", pipelines)[1:]
        por_pipeline = {b.split("'", 1)[0]: re.findall(r"\['([^']+)', '#[0-9A-F]+', :(?:active|completed|cancelled)", b) for b in blocos}
        self.assertEqual(por_pipeline, {
            'Comercial': ['Novo lead', 'Qualificado', 'Proposta enviada', 'Negociação', 'Ganho', 'Perdido'],
            'Pós-venda e recompra': ['Cliente ativo', 'Acompanhamento', 'Pedido de indicação', 'Recompra'],
            'Prospecção': ['Lista com opt-in', 'Primeiro contato enviado', 'Respondeu', 'Qualificado', 'Passou para o comercial', 'Sem interesse', 'Não contatar'],
        })
        self.assertIn("'Ganho', '#10B981', :completed", pipelines)
        self.assertIn("'Perdido', '#9CA3AF', :cancelled", pipelines)
        self.assertIn("'Passou para o comercial', '#10B981', :completed", pipelines)
        self.assertIn("'Sem interesse', '#9CA3AF', :cancelled", pipelines)
        self.assertIn("'Não contatar', '#DC2626', :cancelled", pipelines)

    def test_etiquetas_prospeccao_sem_duplicar(self):
        labels = SOURCE.split('LABELS = [', 1)[1].split('ATTRIBUTES = [', 1)[0]
        titulos = re.findall(r"^\s*\['([^']+)',", labels, re.M)
        self.assertEqual(len(titulos), len(set(titulos)))
        for t in ('prospeccao', 'opt-in', 'opt-out'):
            self.assertIn(t, titulos)

    def test_busca_de_etapa_e_sempre_por_pipeline(self):
        # 'Qualificado' existe em Comercial e em Prospecção: a criação e o tracking precisam filtrar pelo pipeline.
        self.assertIn("pipeline.pipeline_stages.exists?(name: name)", SOURCE)
        self.assertIn("Pipeline.find_by(name: pipe)&.pipeline_stages&.find_by(name: name)&.id", SOURCE)
        self.assertNotIn("PipelineStage.find_by(name", SOURCE)
        self.assertNotIn("PipelineStage.exists?(name", SOURCE)

    def test_prospeccao_nao_altera_tracking(self):
        self.assertIn("stage.call('Comercial', 'Qualificado')", SOURCE)
        self.assertNotIn("stage.call('Prospecção'", SOURCE)

    def test_campos_macros_e_tracking(self):
        for value in ('origem_lead', 'servico_interesse', 'orcamento_estimado', 'proxima_acao', 'nao_contatar', 'opt-out', 'Boas-vindas', 'Pedir orçamento', 'Follow-up', 'Pós-venda', 'TRACKING_STAGE_MEETING_IDS', 'TRACKING_STAGE_CONTRACT_IDS', 'ActiveRecord::Rollback'):
            with self.subTest(value=value):
                self.assertIn(value, SOURCE)

if __name__ == '__main__':
    unittest.main()
