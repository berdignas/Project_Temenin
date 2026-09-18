const fs = require('fs');
const path = require('path');
const { supabaseAdmin } = require('../config/supabase');

const SETTINGS_FILE = path.join(__dirname, '../config/system_settings.json');

const DEFAULT_SETTINGS = {
  price_per_km: 5000,
  price_per_km_sporty: 7500,
  min_ride_price: 15000,
  base_hourly_price: 50000,
  min_hourly_price: 35000,
  sleep_call_package_price: 45000,
  virtual_counseling_hourly_price: 35000,
  gaming_buddy_per_match_price: 15000,
  commission_rate: 10,
  allow_negotiation_flexible_only: true,
  updated_at: new Date().toISOString()
};

// Helper: load local settings
function loadLocalSettings() {
  try {
    if (fs.existsSync(SETTINGS_FILE)) {
      const raw = fs.readFileSync(SETTINGS_FILE, 'utf8');
      return { ...DEFAULT_SETTINGS, ...JSON.parse(raw) };
    }
  } catch (err) {
    console.error('Error reading local settings file:', err.message);
  }
  return { ...DEFAULT_SETTINGS };
}

// Helper: save local settings
function saveLocalSettings(settings) {
  try {
    fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2), 'utf8');
  } catch (err) {
    console.error('Error writing local settings file:', err.message);
  }
}

// 1. Get current settings (Admin)
exports.getSettings = async (req, res) => {
  try {
    let currentSettings = loadLocalSettings();

    try {
      const { data, error } = await supabaseAdmin
        .from('system_settings')
        .select('*')
        .eq('id', 'pricing_config')
        .maybeSingle();

      if (!error && data) {
        currentSettings = { ...currentSettings, ...data };
        saveLocalSettings(currentSettings);
      }
    } catch (dbErr) {
      // Supabase table may not exist yet; use local persistent fallback
    }

    res.status(200).json({
      success: true,
      data: currentSettings
    });
  } catch (error) {
    console.error('Error in getSettings:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// 2. Update settings (Admin)
exports.updateSettings = async (req, res) => {
  try {
    const existing = loadLocalSettings();
    const updated = {
      ...existing,
      price_per_km: req.body.price_per_km !== undefined ? Number(req.body.price_per_km) : existing.price_per_km,
      price_per_km_sporty: req.body.price_per_km_sporty !== undefined ? Number(req.body.price_per_km_sporty) : existing.price_per_km_sporty,
      min_ride_price: req.body.min_ride_price !== undefined ? Number(req.body.min_ride_price) : existing.min_ride_price,
      base_hourly_price: req.body.base_hourly_price !== undefined ? Number(req.body.base_hourly_price) : existing.base_hourly_price,
      min_hourly_price: req.body.min_hourly_price !== undefined ? Number(req.body.min_hourly_price) : existing.min_hourly_price,
      sleep_call_package_price: req.body.sleep_call_package_price !== undefined ? Number(req.body.sleep_call_package_price) : existing.sleep_call_package_price,
      virtual_counseling_hourly_price: req.body.virtual_counseling_hourly_price !== undefined ? Number(req.body.virtual_counseling_hourly_price) : existing.virtual_counseling_hourly_price,
      gaming_buddy_per_match_price: req.body.gaming_buddy_per_match_price !== undefined ? Number(req.body.gaming_buddy_per_match_price) : existing.gaming_buddy_per_match_price,
      commission_rate: req.body.commission_rate !== undefined ? Number(req.body.commission_rate) : existing.commission_rate,
      allow_negotiation_flexible_only: req.body.allow_negotiation_flexible_only !== undefined ? Boolean(req.body.allow_negotiation_flexible_only) : existing.allow_negotiation_flexible_only,
      updated_at: new Date().toISOString()
    };

    saveLocalSettings(updated);

    try {
      await supabaseAdmin
        .from('system_settings')
        .upsert({
          id: 'pricing_config',
          ...updated
        });
    } catch (dbErr) {
      console.warn('Could not upsert system_settings in Supabase, persisted to local file:', dbErr.message);
    }

    res.status(200).json({
      success: true,
      message: 'Pengaturan sistem & tarif layanan berhasil diperbarui',
      data: updated
    });
  } catch (error) {
    console.error('Error in updateSettings:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// 3. Public / Client Pricing Configuration
exports.getPublicPricingConfig = async (req, res) => {
  try {
    let settings = loadLocalSettings();

    try {
      const { data, error } = await supabaseAdmin
        .from('system_settings')
        .select('*')
        .eq('id', 'pricing_config')
        .maybeSingle();

      if (!error && data) {
        settings = { ...settings, ...data };
      }
    } catch (dbErr) {
      // fallback to local
    }

    res.status(200).json({
      success: true,
      data: {
        price_per_km: settings.price_per_km,
        price_per_km_sporty: settings.price_per_km_sporty,
        min_ride_price: settings.min_ride_price,
        base_hourly_price: settings.base_hourly_price,
        min_hourly_price: settings.min_hourly_price,
        sleep_call_package_price: settings.sleep_call_package_price,
        virtual_counseling_hourly_price: settings.virtual_counseling_hourly_price,
        gaming_buddy_per_match_price: settings.gaming_buddy_per_match_price,
        allow_negotiation_flexible_only: settings.allow_negotiation_flexible_only,
        updated_at: settings.updated_at
      }
    });
  } catch (error) {
    console.error('Error in getPublicPricingConfig:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};
