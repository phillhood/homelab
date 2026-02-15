import { registerAs } from '@nestjs/config';

export default registerAs('matrix', () => ({
  synapseUrl: process.env.SYNAPSE_URL || 'http://synapse.matrix.svc.cluster.local:8008',
  serverName: process.env.MATRIX_SERVER_NAME || 'shychedelic.com',
  adminToken: process.env.SYNAPSE_ADMIN_TOKEN || '',
  elementUrl: process.env.ELEMENT_URL || 'https://element.shychedelic.com',
}));
