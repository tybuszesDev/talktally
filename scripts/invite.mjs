#!/usr/bin/env node
// Invites a user to the Cognito user pool of an environment (ADR-0032). Cognito emails the
// invitation with a temporary password; the user sets their own password at the first sign-in.
// Runs the AWS CLI with the administrator session (ADR-0026):
//   aws login --profile talktally-admin
//   AWS_PROFILE=talktally-admin pnpm invite someone@example.com [--env dev|prod] [--resend]

import { execFile } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import { parseArgs, promisify } from 'node:util';

const REGION = 'eu-central-1';
const ENVIRONMENTS = ['dev', 'prod'];
// A shape check against typos only; Cognito validates the address itself.
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const USAGE = 'Usage: pnpm invite <email> [--env dev|prod] [--resend]';

/**
 * Runs one AWS CLI command and returns its standard output (JSON).
 * @typedef {(args: string[]) => Promise<string>} AwsRunner
 */

/**
 * @param {string[]} args command-line arguments after the script name
 * @returns {{ email: string, environment: string, resend: boolean }}
 */
export function parseInviteArguments(args) {
  const { values, positionals } = parseArgs({
    args,
    options: {
      env: { type: 'string', default: 'dev' },
      resend: { type: 'boolean', default: false },
    },
    allowPositionals: true,
  });
  const email = positionals[0];
  if (positionals.length !== 1 || email === undefined) throw new Error(USAGE);
  if (!EMAIL.test(email)) throw new Error(`Not an email address: ${email}\n${USAGE}`);
  if (!ENVIRONMENTS.includes(values.env)) {
    throw new Error(`Unknown environment "${values.env}". Use one of: ${ENVIRONMENTS.join(', ')}.`);
  }
  return { email, environment: values.env, resend: values.resend };
}

/** @param {string} environment */
export function userPoolName(environment) {
  return `talktally-${environment}-users`;
}

/**
 * Lists every user pool of the region. `list-user-pools` requires `--max-results`, and that
 * argument turns off the AWS CLI's automatic pagination, so this follows `NextToken` itself.
 * @param {AwsRunner} runAws
 * @returns {Promise<{ Id: string, Name: string }[]>}
 */
export async function listUserPools(runAws) {
  /** @type {{ Id: string, Name: string }[]} */
  const pools = [];
  /** @type {string | undefined} */
  let nextToken;
  do {
    const args = ['cognito-idp', 'list-user-pools', '--max-results', '60'];
    if (nextToken) args.push('--next-token', nextToken);
    /** @type {{ UserPools?: { Id: string, Name: string }[], NextToken?: string }} */
    const page = JSON.parse(await runAws(args));
    pools.push(...(page.UserPools ?? []));
    nextToken = page.NextToken;
  } while (nextToken);
  return pools;
}

/**
 * Finds the ID of the pool with this exact name.
 * @param {{ Id: string, Name: string }[]} pools
 * @param {string} name
 */
export function findUserPoolId(pools, name) {
  const matches = pools.filter((pool) => pool.Name === name);
  const [match] = matches;
  if (matches.length > 1) throw new Error(`More than one user pool is named ${name}.`);
  if (!match) {
    throw new Error(`No user pool named ${name} in ${REGION}. Is the environment applied?`);
  }
  return match.Id;
}

/**
 * Arguments of `admin-create-user`. A new user gets a verified email: the invitation proves the
 * address when the user signs in with the temporary password. RESEND sends a new temporary
 * password to an existing user.
 * @param {{ userPoolId: string, email: string, resend: boolean }} invitation
 */
export function createUserArguments({ userPoolId, email, resend }) {
  const args = [
    'cognito-idp',
    'admin-create-user',
    '--user-pool-id',
    userPoolId,
    '--username',
    email,
    // Cognito sends the invitation by SMS unless EMAIL is requested.
    '--desired-delivery-mediums',
    'EMAIL',
  ];
  if (resend) return [...args, '--message-action', 'RESEND'];
  const attributes = [
    { Name: 'email', Value: email },
    { Name: 'email_verified', Value: 'true' },
  ];
  return [...args, '--user-attributes', JSON.stringify(attributes)];
}

/**
 * Turns an AWS CLI failure into a message that says what to do.
 * @param {unknown} error
 * @param {{ email: string, poolName: string }} context
 */
export function explainAwsError(error, { email, poolName }) {
  const details = /** @type {{ code?: unknown, stderr?: unknown }} */ (error ?? {});
  if (details.code === 'ENOENT') {
    return 'The AWS CLI is not installed (CONTRIBUTING.md, Prerequisites).';
  }
  const stderr = typeof details.stderr === 'string' ? details.stderr : String(error);
  if (stderr.includes('UsernameExistsException')) {
    return `${email} already has an account in ${poolName}. To send a new temporary password, run again with --resend.`;
  }
  if (stderr.includes('UserNotFoundException')) {
    return `${email} has no account in ${poolName}. Run without --resend to invite them.`;
  }
  if (/credentials|ExpiredToken|aws login/i.test(stderr)) {
    return 'No valid AWS session. Run `aws login --profile talktally-admin` and set AWS_PROFILE=talktally-admin.';
  }
  return stderr.trim();
}

/**
 * @param {string[]} args command-line arguments after the script name
 * @param {AwsRunner} runAws
 * @returns {Promise<string>} the message for the owner
 */
export async function invite(args, runAws) {
  const { email, environment, resend } = parseInviteArguments(args);
  const poolName = userPoolName(environment);
  try {
    const userPoolId = findUserPoolId(await listUserPools(runAws), poolName);
    await runAws(createUserArguments({ userPoolId, email, resend }));
  } catch (error) {
    if (error instanceof Error && !('stderr' in error) && !('code' in error)) throw error;
    throw new Error(explainAwsError(error, { email, poolName }), { cause: error });
  }
  return resend
    ? `Sent a new temporary password to ${email} (${poolName}).`
    : `Invited ${email} to ${poolName}. Cognito emails the temporary password.`;
}

/** @type {AwsRunner} */
async function runAwsCli(args) {
  // execFile passes the arguments without a shell, so an email cannot inject a command.
  const { stdout } = await promisify(execFile)('aws', [
    ...args,
    '--region',
    REGION,
    '--output',
    'json',
  ]);
  return stdout;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    console.log(await invite(process.argv.slice(2), runAwsCli));
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}
