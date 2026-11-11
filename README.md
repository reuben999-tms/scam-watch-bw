# Scam Watch BW

A scam reporting and awareness site for Botswana. People report scams, reviewers verify them, and only verified alerts become public. Includes a moderated group chat that blocks personal information, and a separate admin console.

**Stack:** static site (`index.html` + `config.js`) hosted on GitHub Pages, with Supabase for the database, sign-in and security rules. No build step.

## Files
- `index.html`: the whole app (public side and admin console)
- `config.js`: your Supabase URL and anon key
- `schema.sql`: tables, security rules, server-side guards and the publish function
- `README.md`: this guide

## Preview it on your computer
- **Quick look:** double-click `index.html`. While `config.js` still has the placeholder values, the site opens in preview mode with sample alerts so you can see the layout. Sign-in, reporting, chat and the admin console are switched off in this mode.
- **Full test:** after setting up Supabase, run `python3 -m http.server 8000` in this folder and open `http://localhost:8000`. Add `http://localhost:8000` to the Redirect URLs in Supabase (Authentication > URL Configuration) so sign-in links work.

## 1. Set up Supabase (free tier is fine to start)
1. Create a project at supabase.com.
2. Open **SQL Editor**, paste all of `schema.sql`, and run it. It seeds `mofenyi157@gmail.com` as the first admin.
3. Go to **Project Settings > API**. Copy the Project URL and the `anon` public key into `config.js`.
4. Go to **Authentication > Providers** and make sure Email is enabled (magic link sign-in).
5. **Before launch, set up custom SMTP** (Authentication > Emails > SMTP Settings, for example with Resend or Brevo). Supabase's built-in email sender allows only a few emails per hour, so sign-in links will fail once people start joining.

## 2. Host on GitHub Pages
1. Create a GitHub repository and upload these four files to the root.
2. Go to **Settings > Pages**, choose the `main` branch and the `/ (root)` folder, and save. Your site will be at `https://YOUR-USERNAME.github.io/REPO-NAME/`.
3. In Supabase, go to **Authentication > URL Configuration**. Set **Site URL** to your Pages address and add the same address under **Redirect URLs**. Without this, sign-in links will not return to your site.
4. Optional: add a custom domain in GitHub Pages settings.

## 3. How it works
- **Public:** anyone can read verified alerts and search a number, handle or website. No sign-in needed.
- **Members:** sign in with an email link to report a scam or use the chat. Email is used only for sign-in. It is never shown, never attached to reports, and chat shows anonymous handles like "Member 4f2a".
- **Admins:** see the Admin console automatically. They review reports, publish alerts, moderate chat, and add or remove admins (Admins tab).
- **Statuses:** Received, Under review, Reported (needs 3 independent reporters, enforced by the database), Confirmed (needs the reviewer's evidence check), Rejected.
- **Categories:** 11 scam types with a red-flags guide. Reviewers can change the category before publishing.
- **Chat guard:** the database blocks long digit strings (phone, ID, account numbers), emails, links and phrases like "I live in" or "call me". It is pattern matching, so keep moderating.
- **Limits:** 20 reports per person per day, one chat message per 2 seconds.

## 4. Moderation guide
1. Check the Review tab at least once or twice a day.
2. For each report: read the evidence, look at how many independent people reported the same identifier, and check public details (domain age, whether the business really exists).
3. Write the public summary yourself. Describe what happened, never name a person, and remove any details about the reporter.
4. Use **Reported** for several independent reports, **Confirmed** only with strong evidence. Neither is a court finding.
5. Disputes (people saying a listing is wrong) are handled first. If the dispute is right, remove the alert straight away from the Published tab.
6. Delete chat messages that contain personal information or abuse.
7. Keep original evidence untouched, never contact scammers, and send serious cases to the Botswana Police Service. Do not promise anyone their money back.

## 5. Privacy notice (template, have a lawyer review it)
> We collect your email address only to sign you in. We do not publish it or attach it to your reports. Reports are reviewed before anything is published, and we only publish the scammer's number, handle or website, the scam type and a short summary. Do not include your own personal information in reports or chat. To ask us to correct or delete information about you, contact [your contact email]. This site is not a police or government service.

Botswana's Data Protection Act is now in force, so get legal advice on registration, your privacy notice and terms of use before a public launch.

## 6. Launch checklist
- [ ] `schema.sql` ran without errors
- [ ] `config.js` has your real URL and anon key (not the service_role key)
- [ ] Custom SMTP set up and a test sign-in email received
- [ ] Site URL and Redirect URLs set in Supabase
- [ ] Test as a member: report, chat, try posting a phone number (it should be blocked)
- [ ] Test as admin: review, publish an alert, remove it, add and remove an admin
- [ ] Test data deleted
- [ ] Privacy notice and terms reviewed
- [ ] Someone is ready to moderate daily
- [ ] First TikTok announcement ready

## 7. Known limits and next steps
- "Independent reporters" means different accounts. Someone could create several email accounts, so judge evidence, not just counts.
- Add CAPTCHA (Supabase supports Cloudflare Turnstile) if you get spam sign-ups.
- Screenshot uploads are not included yet. They can be added with Supabase Storage.
- `chat_view` is a normal (security definer) view on purpose, so members can read chat without reading the messages table. Supabase may show a lint warning about it. That is expected.
