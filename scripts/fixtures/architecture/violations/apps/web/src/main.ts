// apps-not-to-other-apps
import { mobile } from '../../mobile/src/app';
// not-to-dev-dep: typescript is a devDependency in ../package.json
import ts from 'typescript';

export const web = `${mobile} ${ts.version}`;
