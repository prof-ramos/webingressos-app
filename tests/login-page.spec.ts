import { test, expect } from "@playwright/test"
import AxeBuilder from "@axe-core/playwright"

test("login expõe heading principal, campos nomeados e acessibilidade básica", async ({ page }) => {
  await page.goto("/login")

  await expect(
    page.getByRole("heading", { name: "Entrar na operação", level: 1 })
  ).toBeVisible()
  await expect(page.getByLabel("E-mail")).toBeVisible()
  await expect(page.getByLabel("Senha")).toBeVisible()

  const accessibilityResults = await new AxeBuilder({ page }).analyze()
  expect(accessibilityResults.violations).toEqual([])
})

test("login apresenta falhas recebidas pelo fluxo de autenticação", async ({ page }) => {
  await page.goto("/login?error=auth_callback_failed&next=%2Fdashboard")

  await expect(
    page.getByText("Não foi possível concluir a autenticação. Tente entrar novamente.", {
      exact: true,
    })
  ).toBeVisible()
})

test("login ignora códigos de erro não reconhecidos", async ({ page }) => {
  const response = await page.goto("/login?error=toString")

  expect(response?.status()).toBe(200)
  await expect(page.getByText("function toString()", { exact: false })).toHaveCount(0)
})
