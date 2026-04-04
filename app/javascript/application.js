// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

async function copyToClipboard(text) {
	if (navigator.clipboard && window.isSecureContext) {
		await navigator.clipboard.writeText(text)
		return true
	}

	const temporaryInput = document.createElement("input")
	temporaryInput.value = text
	temporaryInput.setAttribute("readonly", "")
	temporaryInput.style.position = "absolute"
	temporaryInput.style.left = "-9999px"
	document.body.appendChild(temporaryInput)
	temporaryInput.select()
	const copied = document.execCommand("copy")
	document.body.removeChild(temporaryInput)
	return copied
}

function flashSharedState(button) {
	if (!button) return
	const originalText = button.textContent
	button.classList.add("is-shared")
	button.textContent = "Link Copied"

	window.setTimeout(() => {
		button.classList.remove("is-shared")
		button.textContent = originalText
	}, 1600)
}

async function shareApp(button) {
	const shareData = {
		title: "OTR Tracker",
		text: "Track invoices, expenses, miles, and taxes with OTR Tracker.",
		url: window.location.origin
	}

	if (navigator.share) {
		try {
			await navigator.share(shareData)
			return
		} catch (error) {
			if (error && error.name === "AbortError") return
		}
	}

	const copied = await copyToClipboard(shareData.url)
	if (copied) {
		flashSharedState(button)
		return
	}

	window.prompt("Copy this app link:", shareData.url)
}

document.addEventListener("turbo:load", () => {
	const shareButton = document.querySelector("[data-share-app]")
	if (!shareButton || shareButton.dataset.boundShare === "true") return

	shareButton.dataset.boundShare = "true"
	shareButton.addEventListener("click", async () => {
		await shareApp(shareButton)
	})
})
