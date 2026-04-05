import './style.css'
import { createSolunaRuntime, loadSolunaAppFactory } from './runtime'
import { initPersistentStorage } from './storage'

function requireElement<T extends Element>(selector: string): T {
  const element = document.querySelector<T>(selector)
  if (!element) {
    throw new Error(`Missing required element: ${selector}`)
  }
  return element
}

function resolveAssetUrl(path: string): string {
  return new URL(path, new URL(import.meta.env.BASE_URL, window.location.href)).toString()
}

async function fetchRuntimeFile(path: string): Promise<Uint8Array> {
  const response = await fetch(resolveAssetUrl(path))
  if (!response.ok) {
    throw new Error(`HTTP ${response.status} while fetching ${path}`)
  }
  return new Uint8Array(await response.arrayBuffer())
}

const app = requireElement<HTMLDivElement>('#app')
app.innerHTML = `
  <div id="overlay">
    <div id="status">Loading...</div>
  </div>
  <canvas id="canvas"></canvas>
`

const overlay = requireElement<HTMLElement>('#overlay')
const status = requireElement<HTMLElement>('#status')
const canvas = requireElement<HTMLCanvasElement>('#canvas')

canvas.addEventListener('contextmenu', (event) => {
  event.preventDefault()
})

function setStatus(message: string): void {
  status.textContent = message
}

async function start(): Promise<void> {
  try {
    setStatus('Loading runtime...')
    const runtimeUrl = resolveAssetUrl('runtime/soluna.js')
    const runtimeBaseUrl = resolveAssetUrl('runtime/')

    const [appFactory, mainArchive] = await Promise.all([
      loadSolunaAppFactory(runtimeUrl),
      fetchRuntimeFile('runtime/main.zip'),
    ])

    setStatus('Starting game...')
    await createSolunaRuntime({
      appBaseUrl: runtimeBaseUrl,
      appFactory,
      arguments: ['zipfile=/data/main.zip'],
      canvas,
      files: [
        { path: '/data/main.zip', data: mainArchive, canOwn: true },
      ],
      onAbort(reason) {
        console.error('Program aborted:', reason)
        setStatus('Runtime aborted.')
        overlay.classList.remove('hidden')
      },
      onBeforeRun(runtimeModule) {
        runtimeModule.FS_createPath('/', 'data', true, true)
        initPersistentStorage(runtimeModule)
      },
      print: console.log,
      printErr: console.error,
    })

    overlay.classList.add('hidden')
  }
  catch (error) {
    console.error(error)
    setStatus(error instanceof Error ? error.message : 'Failed to start runtime.')
    overlay.classList.remove('hidden')
  }
}

void start()
