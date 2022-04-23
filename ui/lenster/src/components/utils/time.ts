export const CalculateHarbergerTaxDepositDuration = (
  salePrice,
  yearlyTaxRate,
  depositAmount
) => {
  let yearlyPaymentRate = salePrice * yearlyTaxRate
  const secondsInYear = 31622400
  let perSecondPaymentAmount = yearlyPaymentRate / secondsInYear
  return depositAmount / perSecondPaymentAmount
}
