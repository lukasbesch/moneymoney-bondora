WebBanking {
  version = 1.1,
  url = "https://www.bondora.com",
  description = "Bondora Account",
  services = { "Bondora Account" }
}

-- Custom Build

local unicode = require "utf8"

-- State
local connection = Connection()
local html

-- Constants
local currency = "EUR"

function SupportsBank (protocol, bankCode)
  return protocol == ProtocolWebBanking and bankCode == "Bondora Account"
end

function InitializeSession (protocol, bankCode, username, username2, password, username3)
  MM.printStatus("Login")

  -- Fetch login page
  connection.language = "de-de"
  html = HTML(connection:get("https://www.bondora.com/de/login"))

  html:xpath("//input[@name='Email']"):attr("value", username)
  html:xpath("//input[@name='Password']"):attr("value", password)

  connection:request(html:xpath("//form[contains(@action, 'login')]//button[@type='submit']"):click())

  if string.match(connection:getBaseURL(), 'login') then
    MM.printStatus("Login Failed")
    return LoginFailed
  end
end

function ListAccounts (knownAccounts)
  -- Parse account info
  local account = {
    name = "Bondora Summary",
    accountNumber = "Bondora Summary",
    currency = currency,
    portfolio = true,
    type = "AccountTypePortfolio"
  }

  return account
end

function AccountSummary ()
  local headers = {accept = "application/json"}
  local content = connection:request(
    "GET",
    "https://www.bondora.com/de/dashboard/overviewnumbers/",
    "",
    "application/json",
    headers
  )
  return JSON(content):dictionary()
end

function AccountSummaryGoAndGrow ()
  local headers = {accept = "text/html"}
  local content = connection:request(
    "GET",
    "https://www.bondora.com/de/gogrow/",
    "",
    "application/json",
    headers
  )

  html = HTML(connection:get("https://www.bondora.com/de/gogrow/"))
  html = html:xpath("//table[@class='fund__information']")

  local summary = {
    yourContribution = html:xpath("//td[@class='js-your-contribution']"):text(),
    potentialGain = html:xpath("//td[@class='js-potential-gain']"):text(),
    total = html:xpath("//td[@class='js-total']"):text(),
  }

  for k,v in pairs(summary) do
    v = string.gsub(v, "%s+", "")       -- remove whitespaces
    v = utf8sub( v, 0, utf8len(v) - 1 ) -- remove euro character
    v = utf8replace( v, {["."] = ""} )  -- remove thousands separator dots
    v = utf8replace( v, {[","] = "."} ) -- replace comma with dot
    v = tonumber( v )
    summary[k] = v
  end

  summary.currentGain = round( ((summary.total / summary.yourContribution) - 1) * 100, 2 )

  return summary
end

function RefreshAccount (account, since)
  local s = {}

  -- go & grow

  local summaryGoAndGrow = AccountSummaryGoAndGrow()

  local securityGoAndGrow = {
    name = "Go & Grow",
    price = summaryGoAndGrow.total,
    quantity = 1,
    purchasePrice = summaryGoAndGrow.yourContribution,
    curreny = nil,
  }

  table.insert(s, securityGoAndGrow)

  -- general account

  summary = AccountSummary()

  local value = summary.Stats[1].Value
  local profit = summary.Stats[2].Value
  profit = string.gsub(profit, "[^%d]", "")
  value = string.gsub(value, "[^%d]", "")

  local security = {
    name = "Account",
    price = tonumber(value) - tonumber(securityGoAndGrow.price),
    quantity = 1,
    purchasePrice = tonumber(value) - tonumber(profit) - tonumber(securityGoAndGrow.purchasePrice),
    curreny = nil,
  }

  table.insert(s, security)

  return {securities = s}
end


function EndSession ()
  connection:get("https://www.bondora.com/de/authorize/logout/")
  return nil
end

function round(val, decimal)
  if (decimal) then
    return math.floor( (val * 10^decimal) + 0.5) / (10^decimal)
  else
    return math.floor(val+0.5)
  end
end
