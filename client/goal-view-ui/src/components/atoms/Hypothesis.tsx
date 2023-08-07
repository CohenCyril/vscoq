import React, {FunctionComponent} from 'react';

import classes from './Hypothesis.module.css';
import { PpString } from '../../types';
import { fragmentOfPpString } from '../../utilities/pp';

type HypothesisProps = {
    identifiers: string[], 
    type: PpString,
};

const hypothesis: FunctionComponent<HypothesisProps> = (props) => {
    
    const {identifiers, type} = props;

    const idString = identifiers.slice(1).reduce((pre, curr) => {
        return pre + ", " + curr;
    }, identifiers[0]);

    return (
        <li className={classes.Hypothesis}>
            <span className={classes.IdentifierBlock}>
                <span className={classes.Identifier}>{idString}</span>
                <span className={classes.Separator}> : </span>
            </span>
            <span className={classes.Type}>{fragmentOfPpString(type, classes)}</span>
            <br/>
        </li>
    );
};

export default hypothesis;
