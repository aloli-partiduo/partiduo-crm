# SPDX-License-Identifier: AGPL-3.0-or-later

require "../spec_helper"

# Traductions des écrans de l'extension (ADR-005 D7) : chaque route de
# `/ext/CRM/` servie en `GET` (liste tirée du routeur de Marten),
# obtenue dans chaque langue de l'interface par un administrateur, sur
# un jeu de données varié : organisations prospect et cliente, contacts
# (l'un opposé), opportunités ouverte, gagnée (devis émis) et perdue,
# activités en retard, à venir et faite. Contrôle de l'interface
# (`PartiduoUi::Translations`) : ni marqueur de traduction absente, ni
# clé brute, ni interpolation non résolue, et toute route atteinte par
# les liens des pages.

private alias S = Crm::SpecSupport
private alias Api = Crm::Api

describe "Traductions des écrans CRM (langues de l'interface)" do
  it "rend chaque écran dans chaque langue, sans clé absente, brute ni interpolation non résolue" do
    browser = PartiduoUi::Books.admin
    S.user("bruno@example.com", "Bruno")
    S.activate

    leroux = S.organization("Menuiserie Leroux", siren: "732829320", city: "Lyon")
    morel = S.organization("Atelier Morel", city: "Nantes")
    paul = S.contact("Leroux", leroux.id, first_name: "Paul", email: "paul@example.com")
    claire = S.contact("Morel", morel.id, first_name: "Claire")
    Api.record_opposition(S.seller, claire.id, "Ne plus démarcher.").value!
    S.contact("Durand", first_name: "Léa")

    S.opportunity("Agencement boutique", leroux.id, contact_id: paul.id, amount: "12000")
    won = S.opportunity("Cuisine", leroux.id, amount: "7000")
    quote = Api.create_quote(S.seller, won.id).value!
    S.issue_quote(quote, "7000")
    Api.move_opportunity(S.writer, won.id, Api::MoveInput.new(S.stage("won").id)).value!
    lost = S.opportunity("Escalier", morel.id, amount: "3000")
    Api.move_opportunity(S.writer, lost.id, Api::MoveInput.new(S.stage("lost").id, Api.loss_reasons(S.system).first.id,
      "Trop cher")).value!

    Api.create_activity(S.seller, Api::ActivityInput.new(kind: "call", subject: "Rappeler Paul", due_on: S.today - 3.days,
      organization_id: leroux.id, contact_id: paul.id)).value!
    Api.create_activity(S.seller, Api::ActivityInput.new(kind: "meeting", subject: "Visite atelier", due_on: S.today + 5.days,
      organization_id: morel.id)).value!
    done = Api.create_activity(S.seller, Api::ActivityInput.new(kind: "task", subject: "Envoyer la plaquette",
      opportunity_id: lost.id)).value!
    Api.complete_activity(S.seller, done.id, report: "Envoyée.").value!

    explorer = PartiduoUi::Translations::Explorer.new(&.name.starts_with?("crm:"))
    # Les requêtes laissent active la dernière langue obtenue (nl) : la
    # langue d'avant est rendue aux exemples suivants.
    locale = I18n.locale
    begin
      explorer.crawl(browser, "CRM")
    ensure
      I18n.activate(locale)
    end
    puts "\nTraductions de CRM : #{explorer.report}"
    (explorer.failures + explorer.unreached.map { |route| "route jamais atteinte : #{route}" }).should eq([] of String)
  end
end
