/**
 * WhatsApp Cloud API Service (Official Meta Graph API)
 * 
 * Mengirimkan pesan OTP dan notifikasi resmi menggunakan Meta WhatsApp Cloud API.
 * Dokumentasi: https://developers.facebook.com/docs/whatsapp/cloud-api
 */

const WHATSAPP_API_VERSION = 'v20.0';

/**
 * Format nomor telepon ke standar internasional WhatsApp (E.164 tanpa tanda +)
 * Contoh: 081234567890 -> 6281234567890
 */
const formatPhoneForWhatsApp = (phone) => {
  let cleaned = phone.replace(/\D/g, '');
  if (cleaned.startsWith('0')) {
    cleaned = '62' + cleaned.substring(1);
  } else if (!cleaned.startsWith('62')) {
    cleaned = '62' + cleaned;
  }
  return cleaned;
};

/**
 * Mengirimkan kode OTP menggunakan Template Pesan Resmi Meta (Authentication Category)
 * @param {string} phone - Nomor tujuan (misal: 08123456789 atau 628123456789)
 * @param {string} otpCode - Kode 6 digit OTP
 * @returns {Promise<{success: boolean, messageId?: string, error?: any}>}
 */
const sendOtpWhatsApp = async (phone, otpCode) => {
  const phoneNumberId = process.env.WHATSAPP_PHONE_NUMBER_ID;
  const accessToken = process.env.WHATSAPP_ACCESS_TOKEN;
  const templateName = process.env.WHATSAPP_TEMPLATE_NAME || 'otp_verification';
  const languageCode = process.env.WHATSAPP_LANGUAGE_CODE || 'id';

  const formattedRecipient = formatPhoneForWhatsApp(phone);

  // Jika credential Meta belum diatur di .env, fallback ke mode simulasi (console log)
  if (!phoneNumberId || !accessToken) {
    console.log('\n======================================================');
    console.log('⚠️ [META WHATSAPP API: SIMULATION MODE]');
    console.log(`Creds belum diset di .env. Pesan OTP disimulasikan:`);
    console.log(`Target: +${formattedRecipient}`);
    console.log(`Kode OTP: ${otpCode}`);
    console.log('======================================================\n');
    return {
      success: true,
      simulation: true,
      message: 'OTP berhasil disimulasikan (Credentials Meta belum diisi di .env)'
    };
  }

  try {
    const url = `https://graph.facebook.com/${WHATSAPP_API_VERSION}/${phoneNumberId}/messages`;

    /**
     * Payload standar Meta Authentication Template dengan tombol copy code
     */
    const payload = {
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to: formattedRecipient,
      type: 'template',
      template: {
        name: templateName,
        language: {
          code: languageCode
        },
        components: [
          {
            type: 'body',
            parameters: [
              {
                type: 'text',
                text: otpCode
              }
            ]
          },
          {
            type: 'button',
            sub_type: 'url',
            index: '0',
            parameters: [
              {
                type: 'text',
                text: otpCode
              }
            ]
          }
        ]
      }
    };

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    });

    const data = await response.json();

    if (!response.ok) {
      console.error('❌ Meta WhatsApp Cloud API Error:', JSON.stringify(data, null, 2));
      return {
        success: false,
        error: data.error?.message || 'Gagal mengirim pesan via WhatsApp Cloud API'
      };
    }

    console.log(`✅ [META WHATSAPP API] OTP berhasil terkirim ke +${formattedRecipient} (Msg ID: ${data.messages?.[0]?.id})`);
    return {
      success: true,
      messageId: data.messages?.[0]?.id,
      data
    };
  } catch (error) {
    console.error('❌ Network error saat memanggil Meta WhatsApp API:', error);
    return {
      success: false,
      error: error.message
    };
  }
};

module.exports = {
  sendOtpWhatsApp,
  formatPhoneForWhatsApp
};
