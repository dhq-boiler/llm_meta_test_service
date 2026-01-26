import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="chats-form"
export default class extends Controller {
  static targets = ["text", "prompt", "submit", "model", "apiKey"]

  connect() {

    this.#setDefaultApiKeyAndModel()
    this.updateSubmitButton()
  }

  apiKeyChanged(event) {
    const selectedValue = event.target.value
    const modelsData = event.target.dataset.models

    if (!selectedValue || !modelsData) {
      this.#clearModelSelect()
      return
    }

    try {
      const allModels = JSON.parse(modelsData)
      const selectedKey = allModels.find((item) => item.value === selectedValue)

      if (selectedKey?.models) {
        this.#populateModelSelect(selectedKey.models)
      } else {
        this.#clearModelSelect()
      }
    } catch (e) {
      console.error("Failed to parse models data:", e)
      this.#clearModelSelect()
    }
  }

  updateSubmitButton() {
    this.submitTarget.disabled = !this.#canSubmit()
  }

  #setDefaultApiKeyAndModel() {
    const urlParams = new URLSearchParams(window.location.search)
    const defaultApiKey = urlParams.get("api_key_uuid")

    if (defaultApiKey && this.hasApiKeyTarget) {
      // Verify that the API key exists in the select options
      const option = Array.from(this.apiKeyTarget.options).find(
        (o) => o.value === defaultApiKey
      )
      if (option) {
        this.apiKeyTarget.value = option.value

        // Generate model list based on selected API key
        this.apiKeyChanged({ target: this.apiKeyTarget })

        // Set default model after model list is generated
        this.#setDefaultModel()
      }
    }
  }

  #setDefaultModel() {
    const urlParams = new URLSearchParams(window.location.search)
    const defaultModel = urlParams.get("model")

    if (defaultModel && this.hasModelTarget) {
      const option = Array.from(this.modelTarget.options).find(
        (o) => o.value === defaultModel
      )
      if (option) {
        this.modelTarget.value = option.value
      }
    }
  }

  #populateModelSelect(models) {
    if (!this.hasModelTarget) return

    this.modelTarget.innerHTML =
      '<option value="">Please select a model</option>'
    this.modelTarget.disabled = false

    for (const model of models) {
      const option = document.createElement("option")
      option.value = model.value
      option.textContent = model.label
      this.modelTarget.appendChild(option)
    }

    // Explicitly update submit button state after populating models
    this.updateSubmitButton()
  }

  #clearModelSelect() {
    if (!this.hasModelTarget) return

    this.modelTarget.innerHTML =
      '<option value="">Please select API key first</option>'
    this.modelTarget.disabled = true
    this.updateSubmitButton()
  }

  #canSubmit() {
    // Text field and prompt field can be validated using HTML5's required attribute,
    // so we delegate to checkValidity() to utilize standard validation
    const textField = this.hasTextTarget ? this.textTarget : null
    const promptField = this.promptTarget

    // Use HTML5 standard validation
    const basicFieldsValid =
      (!textField || textField.checkValidity()) && promptField.checkValidity()

    const isGuest = this.element.dataset.guest === "true"

    if (isGuest) {
      return basicFieldsValid
    }

    // API Key and Model selects require JavaScript validation for the following reasons:
    // 1. Model select is dynamically enabled/disabled based on API Key selection
    // 2. Disabled selects are not validated by checkValidity()
    // 3. The dependency between the two selects (Model cannot be selected without API Key) cannot be expressed with HTML attributes alone
    const apiKeySelect = document.querySelector('select[name="api_key_uuid"]')
    const modelSelect = this.hasModelTarget
      ? this.modelTarget
      : document.querySelector('select[name="model"]')

    const apiKeySelected = apiKeySelect?.value
    const modelSelected = modelSelect?.value && !modelSelect.disabled


    return basicFieldsValid && apiKeySelected && modelSelected
  }
}


