const crypto = require('crypto');

class XenditService {
  constructor() {
    this.baseUrl = 'https://api.xendit.co';
  }

  /**
   * Helper to get Authorization Header for Xendit API (Basic Auth using Secret Key)
   */
  getHeaders() {
    const secretKey = process.env.XENDIT_SECRET_KEY || '';
    const base64Key = Buffer.from(`${secretKey}:`).toString('base64');
    return {
      'Content-Type': 'application/json',
      'Authorization': `Basic ${base64Key}`
    };
  }

  /**
   * Generate Dynamic QRIS Code for a booking payment
   */
  async createQrisCode({ bookingId, amount, externalId }) {
    try {
      const secretKey = process.env.XENDIT_SECRET_KEY || '';
      
      // If Secret Key is placeholder or empty, fallback to Simulated Test QRIS for development
      if (!secretKey || secretKey.includes('GANTI_DENGAN')) {
        console.log('⚠️ Xendit Secret Key is using placeholder. Returning Simulated QRIS response.');
        return {
          id: `qr_simulated_${Date.now()}`,
          external_id: externalId || `booking_${bookingId}`,
          amount: amount,
          qr_string: `00020101021226680016ID.CO.XENDIT.WWW01189360091430000000000215200458115303360540${amount}5802ID5912TEMENIN AJAA6007JAKARTA61051219062070703A016304C7B9`,
          status: 'ACTIVE',
          is_simulated: true,
          created_at: new Date().toISOString()
        };
      }

      // Call Xendit Official QR Code API v2 via native fetch
      const payload = {
        external_id: externalId || `booking_${bookingId}_${Date.now()}`,
        type: 'DYNAMIC',
        amount: Math.round(amount),
        currency: 'IDR'
      };

      // Xendit requires callback_url matching regex with valid FQDN/TLD (fails on localhost).
      // If BACKEND_URL is localhost or not set, fallback to official domain format.
      let webhookUrl = 'https://api.temeninajaa.com/api/payments/xendit-webhook';
      const backendUrl = process.env.BACKEND_URL;
      if (backendUrl && !backendUrl.includes('localhost') && backendUrl.startsWith('http')) {
        webhookUrl = `${backendUrl}/api/payments/xendit-webhook`;
      }
      payload.callback_url = webhookUrl;

      const response = await fetch(`${this.baseUrl}/qr_codes`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify(payload)
      });

      const data = await response.json();
      if (!response.ok) {
        console.error('❌ Detailed Xendit Response Error:', JSON.stringify(data));
        throw new Error(data.message || data.error_code || `Xendit Error ${response.status}`);
      }

      console.log(`✅ Xendit Dynamic QRIS generated for booking #${bookingId}: ${data.id}`);
      return data;
    } catch (error) {
      console.warn('⚠️ Error generating Xendit QRIS:', error.message);
      console.log('🔄 Falling back to Simulated Sandbox QRIS for testing.');
      return {
        id: `qr_simulated_${Date.now()}`,
        external_id: externalId || `booking_${bookingId}`,
        amount: amount,
        qr_string: `00020101021226680016ID.CO.XENDIT.WWW01189360091430000000000215200458115303360540${amount}5802ID5912TEMENIN AJAA6007JAKARTA61051219062070703A016304C7B9`,
        status: 'ACTIVE',
        is_simulated: true,
        created_at: new Date().toISOString()
      };
    }
  }

  /**
   * Verify Xendit Webhook Verification Token (Fail-Closed Security)
   * NEVER bypasses or allows requests when token is unconfigured or empty!
   */
  verifyWebhookToken(reqToken) {
    const expectedToken = (process.env.XENDIT_WEBHOOK_VERIFICATION_TOKEN || '').trim();

    // 🛡️ FAIL-CLOSED SECURITY: Tolak jika token belum dikonfigurasi secara valid
    if (!expectedToken || expectedToken.includes('GANTI_DENGAN')) {
      console.error('🚨 [Security Alert] XENDIT_WEBHOOK_VERIFICATION_TOKEN belum dikonfigurasi di file .env! Menolak seluruh webhook Xendit untuk mencegah bypass pembayaran.');
      return false;
    }

    if (!reqToken || typeof reqToken !== 'string') {
      return false;
    }

    // Gunakan timingSafeEqual untuk mencegah side-channel timing attacks
    const reqBuffer = Buffer.from(reqToken.trim());
    const expectedBuffer = Buffer.from(expectedToken);

    if (reqBuffer.length !== expectedBuffer.length) {
      return false;
    }

    return crypto.timingSafeEqual(reqBuffer, expectedBuffer);
  }

  /**
   * Create Disbursement (Payout) to driver bank account
   */
  async createDisbursement({ externalId, amount, bankCode, accountHolderName, accountNumber, description }) {
    try {
      const secretKey = process.env.XENDIT_SECRET_KEY || '';
      if (!secretKey || secretKey.includes('GANTI_DENGAN')) {
        console.log('⚠️ Xendit Secret Key is placeholder. Simulating Driver Disbursement.');
        return {
          id: `disb_simulated_${Date.now()}`,
          external_id: externalId,
          amount: amount,
          status: 'COMPLETED',
          is_simulated: true
        };
      }

      const payload = {
        external_id: externalId,
        amount: Math.round(amount),
        bank_code: bankCode || 'BCA',
        account_holder_name: accountHolderName,
        account_number: accountNumber,
        description: description || 'Pencairan Saldo Bagi Hasil Temenin Ajaa (90%)'
      };

      const response = await fetch(`${this.baseUrl}/disbursements`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify(payload)
      });

      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.message || `Disbursement Error ${response.status}`);
      }

      return data;
    } catch (error) {
      console.error('❌ Error creating Xendit disbursement:', error.message);
      throw new Error(error.message || 'Gagal memproses pencairan ke bank driver');
    }
  }
}

module.exports = new XenditService();
