import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["amount", "paymentDate", "paymentMethod", "submitButton", "walletForm", "paymentMethodSelect"]

  connect() {
    console.log("Payment form controller connected")
    this.requestWallets()
  }

  // MARK: Actions

  async submit(event) {
    event.preventDefault()
    
    const formData = {
      amount: parseFloat(this.amountTarget.value),
      payment_date: this.paymentDateTarget.value,
      payment_method: this.paymentMethodTarget.value
    }
    
    console.log('Payment form submitted:', formData)
    
    // Disable submit button and show loading state
    this.setLoadingState(true)
    
    try {
      // Step 1: Create payment session with Softheon
      const paymentSession = await this.createPaymentSession(formData)
      
      // Step 2: Submit payment to Softheon
      const paymentResult = await this.submitPayment(paymentSession, formData)
      
      // Step 3: Handle successful payment
      this.handlePaymentSuccess(paymentResult)
      
    } catch (error) {
      console.error('Payment error:', error)
      this.handlePaymentError(error)
    } finally {
      this.setLoadingState(false)
    }
  }

  validateAmount(event) {
    const amount = parseFloat(event.target.value)
    if (amount <= 0) {
      event.target.setCustomValidity("Amount must be greater than zero")
    } else {
      event.target.setCustomValidity("")
    }
  }

  validatePaymentMethod(event) {
    const value = event.target.value
    
    if (value === "") {
      event.target.setCustomValidity("Please select a payment method")
    } else {
      event.target.setCustomValidity("")
    }
    
    // Show wallet form if "add_new" is selected
    if (value === 'add_new') {
      this.showWalletForm()
    } else {
      this.hideWalletForm()
    }
  }
  
  /**
   * Toggle between ACH and card fields in wallet form
   */
  toggleWalletFields(event) {
    const walletType = event.target.value
    const achFields = document.getElementById('ach-fields')
    const cardFields = document.getElementById('card-fields')
    
    if (walletType === 'ach') {
      achFields.style.display = 'block'
      cardFields.style.display = 'none'
      this.setFieldsRequired(achFields, true)
      this.setFieldsRequired(cardFields, false)
    } else if (walletType === 'credit_card' || walletType === 'debit_card') {
      achFields.style.display = 'none'
      cardFields.style.display = 'block'
      this.setFieldsRequired(achFields, false)
      this.setFieldsRequired(cardFields, true)
    } else {
      achFields.style.display = 'none'
      cardFields.style.display = 'none'
      this.setFieldsRequired(achFields, false)
      this.setFieldsRequired(cardFields, false)
    }
  }

  // MARK: Softheon API Methods
  
  /**
   * Request available payment wallets from Softheon API
   * @returns {Promise<Object>} Wallet information
   */
  async requestWallets() {
    try {
      const response = await fetch(this.softheonApiUrl('/wallets'), {
        method: 'GET',
        headers: this.getApiHeaders()
      })
      
      if (!response.ok) {
        throw new Error(`Wallet request failed: ${response.statusText}`)
      }
      
      const data = await response.json()
      console.log('Available wallets:', data)
      
      // Update UI with available payment methods based on wallet data
      this.updatePaymentMethods(data)
      
      return data
      
    } catch (error) {
      return null
    }
  }
  
  /**
   * Create a payment session with Softheon
   * @param {Object} formData - Payment form data
   * @returns {Promise<Object>} Payment session data
   */
  async createPaymentSession(formData) {
    const sessionData = {
      account_number: this.accountNumber,
      amount: formData.amount,
      payment_method: formData.payment_method,
      payment_date: formData.payment_date,
      // Metadata for tracking
      metadata: {
        employer_profile_id: this.employerProfileId,
        source: 'enroll_portal'
      }
    }
    
    const response = await fetch(this.softheonApiUrl('/payment-sessions'), {
      method: 'POST',
      headers: this.getApiHeaders(),
      body: JSON.stringify(sessionData)
    })
    
    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.message || 'Failed to create payment session')
    }
    
    return await response.json()
  }
  
  /**
   * Submit payment to Softheon API
   * @param {Object} session - Payment session from createPaymentSession
   * @param {Object} formData - Original form data
   * @returns {Promise<Object>} Payment result
   */
  async submitPayment(session, formData) {
    const paymentData = {
      session_id: session.id,
      amount: formData.amount,
      payment_method: formData.payment_method,
      // Payment method details would be collected in a more complete implementation
      // For now, this is where tokenized payment info would go
      payment_token: session.payment_token || 'PLACEHOLDER_TOKEN'
    }
    
    const response = await fetch(this.softheonApiUrl('/payments'), {
      method: 'POST',
      headers: this.getApiHeaders(),
      body: JSON.stringify(paymentData)
    })
    
    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.message || 'Payment submission failed')
    }
    
    return await response.json()
  }

  // MARK: Helper Methods
  
  /**
   * Update payment method dropdown with wallet data
   * @param {Object} data - Response data from Softheon wallets API
   */
  updatePaymentMethods(data) {
    if (!data || !data.wallets || data.wallets.length === 0) {
      // No wallets available - provide fallback options
      console.warn('No wallets available from API, using fallback payment methods')
      this.provideFallbackPaymentMethods()
      return
    }
    
    const select = this.paymentMethodTarget
    
    // Clear existing options except the placeholder
    while (select.options.length > 1) {
      select.remove(1)
    }
    
    // Update placeholder text
    select.options[0].textContent = 'Select payment method...'
    
    // Add wallet options
    data.wallets.forEach(wallet => {
      if (wallet.status === 'active') {
        const option = document.createElement('option')
        option.value = wallet.id
        option.textContent = this.formatWalletDisplay(wallet)
        
        // Add data attributes for additional wallet info
        option.dataset.walletType = wallet.type
        option.dataset.walletId = wallet.id
        
        select.appendChild(option)
      }
    })
  }
  
  /**
   * Show wallet entry form
   */
  showWalletForm() {
    if (this.hasWalletFormTarget) {
      this.walletFormTarget.style.display = 'block'
    }
  }
  
  /**
   * Hide wallet entry form
   */
  hideWalletForm() {
    if (this.hasWalletFormTarget) {
      this.walletFormTarget.style.display = 'none'
    }
  }
  
  /**
   * Format wallet display text
   * @param {Object} wallet - Wallet object
   * @returns {String} Formatted display text
   */
  formatWalletDisplay(wallet) {
    const typeLabels = {
      'ach': 'Bank Account',
      'credit_card': 'Credit Card',
      'debit_card': 'Debit Card',
      'checking': 'Checking Account',
      'savings': 'Savings Account'
    }
    
    const typeLabel = typeLabels[wallet.type] || wallet.type
    
    // If wallet has a name, use it
    if (wallet.name) {
      return `${typeLabel} - ${wallet.name}`
    }
    
    // If wallet has last4 digits, show them
    if (wallet.last4) {
      return `${typeLabel} ending in ${wallet.last4}`
    }
    
    // Default to just the type
    return typeLabel
  }
  
  /**
   * Get Softheon API headers with authentication
   * @returns {Object} Headers object
   */
  getApiHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // TODO: Replace with actual Softheon API key from environment
      'Authorization': `Bearer ${this.softheonApiKey}`,
      'X-API-Version': '1.0'
    }
  }
  
  /**
   * Build full Softheon API URL
   * @param {String} endpoint - API endpoint path
   * @returns {String} Full URL
   */
  softheonApiUrl(endpoint) {
    return `${this.softheonBaseUrl}${endpoint}`
  }
  
  /**
   * Handle successful payment
   * @param {Object} result - Payment result from Softheon
   */
  handlePaymentSuccess(result) {
    console.log('Payment successful:', result)
    
    // Display success message
    alert(`Payment successful! Transaction ID: ${result.transaction_id}`)
    
    // Optional: Record transaction ID on backend (no sensitive data)
    this.recordTransaction(result.transaction_id, result.amount)
    
    // Redirect to success page or account page
    window.location.href = this.successRedirectUrl
  }
  
  /**
   * Handle payment error
   * @param {Error} error - Error object
   */
  handlePaymentError(error) {
    console.error('Payment error:', error)
    
    // Display user-friendly error message
    const errorMessage = this.getUserFriendlyErrorMessage(error.message)
    alert(`Payment failed: ${errorMessage}`)
  }
  
  /**
   * Convert technical error to user-friendly message
   * @param {String} technicalError - Technical error message
   * @returns {String} User-friendly error message
   */
  getUserFriendlyErrorMessage(technicalError) {
    const errorMap = {
      'insufficient_funds': 'Insufficient funds in account',
      'invalid_account': 'Invalid account number',
      'expired_card': 'Card has expired',
      'card_declined': 'Card was declined',
      'network_error': 'Network connection issue. Please try again.',
      'invalid_amount': 'Invalid payment amount'
    }
    
    // Try to match technical error to user-friendly message
    for (const [key, message] of Object.entries(errorMap)) {
      if (technicalError.toLowerCase().includes(key)) {
        return message
      }
    }
    
    return 'An error occurred processing your payment. Please try again or contact support.'
  }
  
  /**
   * Set loading state on form
   * @param {Boolean} isLoading - Whether form is loading
   */
  setLoadingState(isLoading) {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = isLoading
      this.submitButtonTarget.textContent = isLoading 
        ? 'Processing...' 
        : 'Continue to Payment'
    }
    
    // Could also disable all form inputs during loading
    if (isLoading) {
      this.element.classList.add('is-loading')
    } else {
      this.element.classList.remove('is-loading')
    }
  }
  
  /**
   * Record transaction ID on backend (optional)
   * @param {String} transactionId - Softheon transaction ID
   * @param {Number} amount - Payment amount
   */
  async recordTransaction(transactionId, amount) {
    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
      
      await fetch('/api/payments/record_transaction', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify({
          employer_profile_id: this.employerProfileId,
          transaction_id: transactionId,
          amount: amount,
          payment_date: this.paymentDateTarget.value,
          payment_method: this.paymentMethodTarget.value
        })
      })
    } catch (error) {
      // Non-critical - payment already went through
      console.warn('Failed to record transaction locally:', error)
    }
  }

  // MARK: Getters for configuration
  
  /**
   * Get Softheon API base URL from environment or data attribute
   * @returns {String} Base URL
   */
  get softheonBaseUrl() {
    // Check data attribute first, then fallback to environment variable placeholder
    return this.data.get('apiUrl') || 
           window.SOFTHEON_API_URL || 
           'https://api.softheon.com/v1' // TODO: Replace with actual URL
  }
  
  /**
   * Get Softheon API key
   * @returns {String} API key
   */
  get softheonApiKey() {
    // In production, this should come from backend or secure config
    return this.data.get('apiKey') || 
           window.SOFTHEON_PUBLIC_KEY || 
           'pk_PLACEHOLDER_KEY' // TODO: Replace with actual key
  }
  
  /**
   * Get account number from data attribute
   * @returns {String} Account number
   */
  get accountNumber() {
    return this.data.get('accountNumber')
  }
  
  /**
   * Get employer profile ID from data attribute
   * @returns {String} Employer profile ID
   */
  get employerProfileId() {
    return this.data.get('employerProfileId')
  }
  
  /**
   * Get success redirect URL
   * @returns {String} Redirect URL
   */
  get successRedirectUrl() {
    return this.data.get('successUrl') || 
           window.location.pathname.replace('/pay_now', '')
  }
}

