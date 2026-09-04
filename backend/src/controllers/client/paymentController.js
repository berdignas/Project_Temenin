// backend/src/controllers/client/paymentController.js

// Simple in-memory database of payment methods, keyed by userId
const userPaymentMethods = {};

// Helper to seed default payment methods for a user
const seedDefaultMethods = (userId) => {
  if (!userPaymentMethods[userId]) {
    userPaymentMethods[userId] = [
      {
        id: 'pm-bca-' + Math.random().toString(36).substr(2, 9),
        user_id: userId,
        method_type: 'Virtual Account',
        provider: 'BCA',
        last_four: '8839',
        is_default: true,
        created_at: new Date()
      },
      {
        id: 'pm-gopay-' + Math.random().toString(36).substr(2, 9),
        user_id: userId,
        method_type: 'E-Wallet',
        provider: 'GoPay',
        last_four: null,
        is_default: false,
        created_at: new Date()
      }
    ];
  }
  return userPaymentMethods[userId];
};

class PaymentController {
  /**
   * Get all payment methods for user
   */
  async getPaymentMethods(req, res) {
    try {
      const userId = req.user.id;
      const methods = seedDefaultMethods(userId);
      
      console.log(`\n💳 Retrieved ${methods.length} payment methods for user: ${userId}`);

      res.status(200).json({
        success: true,
        message: 'Payment methods retrieved successfully',
        data: methods
      });
    } catch (error) {
      console.error('Get payment methods error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to retrieve payment methods: ' + error.message
      });
    }
  }

  /**
   * Add a new payment method
   */
  async addPaymentMethod(req, res) {
    try {
      const userId = req.user.id;
      const { method_type, provider } = req.body;

      if (!method_type || !provider) {
        return res.status(400).json({
          success: false,
          message: 'method_type and provider are required'
        });
      }

      const methods = seedDefaultMethods(userId);

      // Generate last_four if it is a Virtual Account or Credit Card
      let last_four = null;
      if (method_type.toLowerCase().includes('card') || method_type.toLowerCase().includes('account')) {
        last_four = Math.floor(1000 + Math.random() * 9000).toString();
      }

      const newMethod = {
        id: 'pm-' + provider.toLowerCase() + '-' + Math.random().toString(36).substr(2, 9),
        user_id: userId,
        method_type,
        provider,
        last_four,
        is_default: methods.length === 0, // Set default if it's the first one
        created_at: new Date()
      };

      methods.push(newMethod);
      console.log(`➕ Added payment method for user ${userId}: ${provider} (${method_type})`);

      res.status(201).json({
        success: true,
        message: 'Payment method added successfully',
        data: newMethod
      });
    } catch (error) {
      console.error('Add payment method error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to add payment method: ' + error.message
      });
    }
  }

  /**
   * Remove a payment method
   */
  async removePaymentMethod(req, res) {
    try {
      const userId = req.user.id;
      const { methodId } = req.params;

      const methods = seedDefaultMethods(userId);
      const index = methods.findIndex(m => m.id === methodId);

      if (index === -1) {
        return res.status(404).json({
          success: false,
          message: 'Payment method not found'
        });
      }

      const [removedMethod] = methods.splice(index, 1);
      console.log(`🗑️ Removed payment method ${methodId} for user ${userId}`);

      // If we removed the default method and have other methods left, make the first one default
      if (removedMethod.is_default && methods.length > 0) {
        methods[0].is_default = true;
      }

      res.status(200).json({
        success: true,
        message: 'Payment method removed successfully'
      });
    } catch (error) {
      console.error('Remove payment method error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to remove payment method: ' + error.message
      });
    }
  }

  /**
   * Set payment method as default
   */
  async setDefaultPaymentMethod(req, res) {
    try {
      const userId = req.user.id;
      const { methodId } = req.params;

      const methods = seedDefaultMethods(userId);
      const methodExists = methods.some(m => m.id === methodId);

      if (!methodExists) {
        return res.status(404).json({
          success: false,
          message: 'Payment method not found'
        });
      }

      methods.forEach(m => {
        m.is_default = m.id === methodId;
      });

      console.log(`⭐ Set default payment method to ${methodId} for user ${userId}`);

      res.status(200).json({
        success: true,
        message: 'Default payment method updated successfully'
      });
    } catch (error) {
      console.error('Set default payment method error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to set default payment method: ' + error.message
      });
    }
  }
}

module.exports = new PaymentController();
