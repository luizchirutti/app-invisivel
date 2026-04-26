# Testar visual no iPhone (alternativa ao Expo Go)

Este projeto e Flutter, então nao roda pelo Expo Go.

A forma mais rapida de validar a cara do app no iPhone e abrir a versao web no Safari do iPhone.

## Passo a passo

1. Conecte iPhone e PC na mesma rede Wi-Fi.
2. No projeto, execute:

powershell -ExecutionPolicy Bypass -File .\scripts\preview_web.ps1

3. O terminal vai mostrar uma URL tipo:

http://SEU_IP:8080

4. Abra essa URL no Safari do iPhone.

## Se o comando flutter nao estiver no PATH

Os scripts agora tentam fallback automatico com `puro flutter`.

Opcionalmente, voce pode testar manualmente:

puro flutter --version

## Quando quiser iOS nativo de verdade

Para instalar no iPhone como app nativo Flutter, voce precisa de macOS + Xcode + Apple Developer.

Fluxo nativo:
1. flutter build ios
2. abrir ios no Xcode
3. assinar e rodar no iPhone

## Observacao

Visual e layout podem ser validados muito bem via web no iPhone.
Recursos nativos (VPN/Kill Switch/Network Extension) precisam de build iOS nativo.
