import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="chats-form"
export default class extends Controller {
  static targets = ["text", "prompt", "submit", "model", "apiKey", "family"]

  connect() {
    this.#setDefaults()
    this.updateSubmitButton()
  }

  familyChanged(event) {
    const selectedFamily = event.target.value
    const familiesData = event.target.dataset.families

    if (!selectedFamily || !familiesData) {
      this.#showApiKeyField()
      this.#clearApiKeySelect()
      this.#clearModelSelect()
      return
    }

    try {
      const families = JSON.parse(familiesData)
      const family = families.find((f) => f.llm_type === selectedFamily)

      if (family?.api_keys) {
        if (selectedFamily === "ollama") {
          // Ollama: skip API key selection entirely, go straight to model
          const apiKey = family.api_keys[0]
          this.#hideApiKeyField()
          this.apiKeyTarget.disabled = false
          this.apiKeyTarget.innerHTML =
            `<option value="${apiKey.uuid}" selected>${apiKey.description}</option>`
          if (apiKey.available_models) {
            this.#populateModelSelect(apiKey.available_models)
          } else {
            this.#clearModelSelect()
          }
        } else {
          this.#showApiKeyField()
          this.#populateApiKeySelect(family.api_keys)
        }
      } else {
        this.#showApiKeyField()
        this.#clearApiKeySelect()
        this.#clearModelSelect()
      }
    } catch (e) {
      console.error("Failed to parse families data:", e)
      this.#clearApiKeySelect()
      this.#clearModelSelect()
    }
  }

  apiKeyChanged(event) {
    const selectedValue = event.target.value
    const familiesData = this.hasFamilyTarget
      ? this.familyTarget.dataset.families
      : null
    const selectedFamily = this.hasFamilyTarget
      ? this.familyTarget.value
      : null

    if (!selectedValue || !familiesData || !selectedFamily) {
      this.#clearModelSelect()
      return
    }

    try {
      const families = JSON.parse(familiesData)
      const family = families.find((f) => f.llm_type === selectedFamily)
      const selectedKey = family?.api_keys?.find(
        (k) => k.uuid === selectedValue
      )

      if (selectedKey?.available_models) {
        this.#populateModelSelect(selectedKey.available_models)
      } else {
        this.#clearModelSelect()
      }
    } catch (e) {
      console.error("Failed to parse families data:", e)
      this.#clearModelSelect()
    }
  }

  updateSubmitButton() {
    this.submitTarget.disabled = !this.#canSubmit()
  }

  // Handle form submission to show user message immediately
  submit() {
    // Don't prevent default - let Turbo handle the form submission
    // Just add the user message to the DOM immediately
    const messageContent = this.promptTarget.value.trim()

    if (!messageContent) {
      return
    }

    // Add user message to the messages list immediately
    this.#addUserMessageToDOM(messageContent)

    // DON'T clear the input here - let the server response handle it
    // Otherwise the POST will be sent with empty value

    // Scroll to bottom
    this.#scrollToBottom()
  }

  #addUserMessageToDOM(content) {
    const messagesList = document.getElementById('messages-list')
    if (!messagesList) return

    // Create message HTML
    const messageDiv = document.createElement('div')
    messageDiv.className = 'message user'
    messageDiv.innerHTML = `
      <div class="message-role">
        👤 You
      </div>
      <div class="message-content">
        <p>${this.#escapeHtml(content)}</p>
      </div>
    `

    messagesList.appendChild(messageDiv)
  }

  #escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  #scrollToBottom() {
    const chatMessages = document.getElementById('chat-messages')
    if (chatMessages) {
      chatMessages.scrollTop = chatMessages.scrollHeight
    }
  }

  #setDefaults() {
    const urlParams = new URLSearchParams(window.location.search)
    const defaultFamily = urlParams.get("family")
    const defaultApiKey = urlParams.get("api_key_uuid")
    const defaultModel = urlParams.get("model")

    if (defaultFamily && this.hasFamilyTarget) {
      const familyOption = Array.from(this.familyTarget.options).find(
        (o) => o.value === defaultFamily
      )
      if (familyOption) {
        this.familyTarget.value = familyOption.value
        this.familyChanged({ target: this.familyTarget })

        if (defaultFamily === "ollama") {
          // Ollama: API key is auto-selected by familyChanged, just set model
          if (defaultModel && this.hasModelTarget) {
            const modelOption = Array.from(this.modelTarget.options).find(
              (o) => o.value === defaultModel
            )
            if (modelOption) {
              this.modelTarget.value = modelOption.value
            }
          }
        } else if (defaultApiKey && this.hasApiKeyTarget) {
          const apiKeyOption = Array.from(this.apiKeyTarget.options).find(
            (o) => o.value === defaultApiKey
          )
          if (apiKeyOption) {
            this.apiKeyTarget.value = apiKeyOption.value
            this.apiKeyChanged({ target: this.apiKeyTarget })

            if (defaultModel && this.hasModelTarget) {
              const modelOption = Array.from(this.modelTarget.options).find(
                (o) => o.value === defaultModel
              )
              if (modelOption) {
                this.modelTarget.value = modelOption.value
              }
            }
          }
        }
      }
    } else if (defaultApiKey && this.hasFamilyTarget) {
      // Fallback: try to find the family from the API key UUID
      this.#setDefaultsFromApiKey(defaultApiKey, defaultModel)
    }
  }

  #setDefaultsFromApiKey(apiKeyUuid, defaultModel) {
    const familiesData = this.hasFamilyTarget
      ? this.familyTarget.dataset.families
      : null
    if (!familiesData) return

    try {
      const families = JSON.parse(familiesData)
      for (const family of families) {
        const key = family.api_keys?.find((k) => k.uuid === apiKeyUuid)
        if (key) {
          this.familyTarget.value = family.llm_type
          this.familyChanged({ target: this.familyTarget })

          if (family.llm_type !== "ollama") {
            this.apiKeyTarget.value = apiKeyUuid
            this.apiKeyChanged({ target: this.apiKeyTarget })
          }

          if (defaultModel && this.hasModelTarget) {
            const modelOption = Array.from(this.modelTarget.options).find(
              (o) => o.value === defaultModel
            )
            if (modelOption) {
              this.modelTarget.value = modelOption.value
            }
          }
          break
        }
      }
    } catch (e) {
      console.error("Failed to set defaults from API key:", e)
    }
  }

  #populateApiKeySelect(apiKeys) {
    if (!this.hasApiKeyTarget) return

    this.apiKeyTarget.innerHTML =
      '<option value="">Please select a service</option>'
    this.apiKeyTarget.disabled = false

    for (const key of apiKeys) {
      const option = document.createElement("option")
      option.value = key.uuid
      option.textContent = key.description
      this.apiKeyTarget.appendChild(option)
    }

    // Clear model when API key list changes
    this.#clearModelSelect()
    this.updateSubmitButton()
  }

  #clearApiKeySelect() {
    if (!this.hasApiKeyTarget) return

    this.apiKeyTarget.innerHTML =
      '<option value="">Please select a family first</option>'
    this.apiKeyTarget.disabled = true
    this.#clearModelSelect()
    this.updateSubmitButton()
  }

  #hideApiKeyField() {
    if (!this.hasApiKeyTarget) return
    this.apiKeyTarget.closest(".api-key-field").classList.add("hidden")
  }

  #showApiKeyField() {
    if (!this.hasApiKeyTarget) return
    this.apiKeyTarget.closest(".api-key-field").classList.remove("hidden")
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
      '<option value="">Please select a service first</option>'
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

    // Family, API Key and Model selects require JavaScript validation
    const familySelect = this.hasFamilyTarget ? this.familyTarget : null
    const apiKeySelect = document.querySelector('select[name="api_key_uuid"]')
    const modelSelect = this.hasModelTarget
      ? this.modelTarget
      : document.querySelector('select[name="model"]')

    const familySelected = familySelect?.value
    const apiKeyHidden = apiKeySelect?.closest(".api-key-field")?.classList.contains("hidden")
    const apiKeySelected = apiKeySelect?.value && (apiKeyHidden || !apiKeySelect.disabled)
    const modelSelected = modelSelect?.value && !modelSelect.disabled

    return basicFieldsValid && familySelected && apiKeySelected && modelSelected
  }
}
