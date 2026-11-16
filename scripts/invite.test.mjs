import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  createUserArguments,
  explainAwsError,
  findUserPoolId,
  invite,
  parseInviteArguments,
  USAGE,
} from './invite.mjs';

const pools = JSON.stringify({
  UserPools: [
    { Id: 'eu-central-1_prod', Name: 'talktally-prod-users' },
    { Id: 'eu-central-1_dev', Name: 'talktally-dev-users' },
  ],
});

/** An AWS CLI failure as execFile reports it. */
function cliError(stderr) {
  return Object.assign(new Error('Command failed'), { code: 254, stderr });
}

/** Records every AWS CLI call and answers from the queue. */
function fakeAws(...answers) {
  const calls = [];
  const run = (args) => {
    calls.push(args);
    const answer = answers.shift();
    return answer instanceof Error ? Promise.reject(answer) : Promise.resolve(answer ?? '{}');
  };
  return { calls, run };
}

describe('parseInviteArguments', () => {
  it('defaults to dev without resend', () => {
    assert.deepEqual(parseInviteArguments(['ala@example.com']), {
      email: 'ala@example.com',
      environment: 'dev',
      resend: false,
    });
  });

  it('reads --env and --resend', () => {
    assert.deepEqual(parseInviteArguments(['ala@example.com', '--env', 'prod', '--resend']), {
      email: 'ala@example.com',
      environment: 'prod',
      resend: true,
    });
  });

  it('requires exactly one email', () => {
    assert.throws(() => parseInviteArguments([]), { message: USAGE });
    assert.throws(() => parseInviteArguments(['a@example.com', 'b@example.com']), {
      message: USAGE,
    });
  });

  it('rejects something that is not an email address', () => {
    assert.throws(() => parseInviteArguments(['ala']), /Not an email address: ala/);
  });

  it('rejects an unknown environment', () => {
    assert.throws(
      () => parseInviteArguments(['ala@example.com', '--env', 'staging']),
      /Unknown environment "staging"/,
    );
  });

  it('rejects an unknown option', () => {
    assert.throws(() => parseInviteArguments(['ala@example.com', '--force']), {
      code: 'ERR_PARSE_ARGS_UNKNOWN_OPTION',
    });
  });
});

describe('findUserPoolId', () => {
  it('returns the pool with the exact name', () => {
    assert.equal(findUserPoolId(pools, 'talktally-dev-users'), 'eu-central-1_dev');
  });

  it('fails when the pool does not exist', () => {
    assert.throws(
      () => findUserPoolId(JSON.stringify({ UserPools: [] }), 'talktally-dev-users'),
      /No user pool named talktally-dev-users/,
    );
  });

  it('fails when two pools have the name', () => {
    const twice = JSON.stringify({
      UserPools: [
        { Id: 'a', Name: 'talktally-dev-users' },
        { Id: 'b', Name: 'talktally-dev-users' },
      ],
    });
    assert.throws(() => findUserPoolId(twice, 'talktally-dev-users'), /More than one user pool/);
  });
});

describe('createUserArguments', () => {
  it('creates the user with a verified email and email delivery', () => {
    assert.deepEqual(
      createUserArguments({ userPoolId: 'pool', email: 'ala@example.com', resend: false }),
      [
        'cognito-idp',
        'admin-create-user',
        '--user-pool-id',
        'pool',
        '--username',
        'ala@example.com',
        '--desired-delivery-mediums',
        'EMAIL',
        '--user-attributes',
        '[{"Name":"email","Value":"ala@example.com"},{"Name":"email_verified","Value":"true"}]',
      ],
    );
  });

  it('resends the invitation without changing attributes', () => {
    assert.deepEqual(
      createUserArguments({ userPoolId: 'pool', email: 'ala@example.com', resend: true }),
      [
        'cognito-idp',
        'admin-create-user',
        '--user-pool-id',
        'pool',
        '--username',
        'ala@example.com',
        '--desired-delivery-mediums',
        'EMAIL',
        '--message-action',
        'RESEND',
      ],
    );
  });
});

describe('explainAwsError', () => {
  const context = { email: 'ala@example.com', poolName: 'talktally-dev-users' };

  it('suggests --resend when the user exists', () => {
    const error = cliError('An error occurred (UsernameExistsException) when calling ...');
    assert.match(explainAwsError(error, context), /already has an account.*--resend/);
  });

  it('suggests inviting when a resend finds no user', () => {
    const error = cliError('An error occurred (UserNotFoundException) when calling ...');
    assert.match(explainAwsError(error, context), /has no account.*without --resend/);
  });

  it('tells how to sign in when there is no session', () => {
    const error = cliError('Unable to locate credentials. You can configure credentials ...');
    assert.match(explainAwsError(error, context), /aws login --profile talktally-admin/);
  });

  it('reports a missing AWS CLI', () => {
    const error = Object.assign(new Error('spawn aws ENOENT'), { code: 'ENOENT' });
    assert.match(explainAwsError(error, context), /AWS CLI is not installed/);
  });

  it('passes other errors through', () => {
    assert.equal(explainAwsError(cliError(' AccessDenied \n'), context), 'AccessDenied');
  });
});

describe('invite', () => {
  it('finds the pool of the environment and creates the user', async () => {
    const aws = fakeAws(pools, '{"User":{}}');
    const message = await invite(['ala@example.com'], aws.run);

    assert.deepEqual(aws.calls[0], ['cognito-idp', 'list-user-pools', '--max-results', '60']);
    assert.deepEqual(aws.calls[1]?.slice(0, 6), [
      'cognito-idp',
      'admin-create-user',
      '--user-pool-id',
      'eu-central-1_dev',
      '--username',
      'ala@example.com',
    ]);
    assert.equal(
      message,
      'Invited ala@example.com to talktally-dev-users. Cognito emails the temporary password.',
    );
  });

  it('uses the prod pool with --env prod', async () => {
    const aws = fakeAws(pools, '{}');
    await invite(['ala@example.com', '--env', 'prod'], aws.run);
    assert.equal(aws.calls[1]?.[3], 'eu-central-1_prod');
  });

  it('reports a resend', async () => {
    const aws = fakeAws(pools, '{}');
    const message = await invite(['ala@example.com', '--resend'], aws.run);
    assert.equal(
      message,
      'Sent a new temporary password to ala@example.com (talktally-dev-users).',
    );
  });

  it('explains an AWS CLI failure', async () => {
    const aws = fakeAws(pools, cliError('An error occurred (UsernameExistsException)'));
    await assert.rejects(invite(['ala@example.com'], aws.run), /run again with --resend/);
  });

  it('does not call AWS when the arguments are wrong', async () => {
    const aws = fakeAws();
    await assert.rejects(invite(['not-an-email'], aws.run), /Not an email address/);
    assert.equal(aws.calls.length, 0);
  });

  it('stops before creating a user when the pool is missing', async () => {
    const aws = fakeAws(JSON.stringify({ UserPools: [] }));
    await assert.rejects(invite(['ala@example.com'], aws.run), /No user pool named/);
    assert.equal(aws.calls.length, 1);
  });
});
