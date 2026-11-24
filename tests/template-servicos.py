#!/usr/bin/env python3
"""Verifica o contrato do template sem exigir um CRM instalado."""
import pathlib
import re
import unittest

SOURCE = (pathlib.Path(__file__).resolve().parents[1] / 'crm/evo-service-crm/templates/servicos.rb').read_text()

class TemplateServicosTest(unittest.TestCase):
    def test_pipelines(self):
        pipelines = SOURCE.split('PIPELINES = [', 1)[1].split('LABELS = [', 1)[0]
        names = re.findall(r"\['([^']+)', '#[0-9A-F]+', :(?:active|completed|cancelled)", pipelines)
        self.assertEqual(names, ['Novo lead', 'Qualificado', 'Proposta enviada', 'Negociação', 'Ganho', 'Perdido', 'Cliente ativo', 'Acompanhamento', 'Pedido de indicação', 'Recompra'])
        self.assertIn("'Ganho', '#10B981', :completed", pipelines)
        self.assertIn("'Perdido', '#9CA3AF', :cancelled", pipelines)

    def test_campos_macros_e_tracking(self):
        for value in ('origem_lead', 'servico_interesse', 'orcamento_estimado', 'proxima_acao', 'nao_contatar', 'opt-out', 'Boas-vindas', 'Pedir orçamento', 'Follow-up', 'Pós-venda', 'TRACKING_STAGE_MEETING_IDS', 'TRACKING_STAGE_CONTRACT_IDS', 'ActiveRecord::Rollback'):
            with self.subTest(value=value):
                self.assertIn(value, SOURCE)

if __name__ == '__main__':
    unittest.main()
